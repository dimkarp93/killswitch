#!/bin/bash
set -Eeuo pipefail

# Selective Kill Switch for the protected destinations.
# This script owns only mark 0x7199 and routing table 7199.
# Other VPN marks/tables/rules are intentionally left untouched.

[[ $EUID -eq 0 ]] || {
    echo "Run as root" >&2
    exit 1
}

command -v nft >/dev/null || { echo "nft is required" >&2; exit 1; }
command -v ip  >/dev/null || { echo "iproute2 is required" >&2; exit 1; }

IF="amn0"
TABLE="7199"
MARK="0x7199"
RULE_PRIORITY="1"

NFT_FAMILY="inet"
NFT_TABLE="killswitch"

# Protected destinations. Edit only these arrays to change the protected ranges.
V4=(
    "160.79.104.0/23"
    "153.61.224.0/22"
)
V6=(
    "2607:6bc0::/48"
)

# ---------------------------------------------------------------------------
# nftables table and sets
# ---------------------------------------------------------------------------

nft list table "$NFT_FAMILY" "$NFT_TABLE" >/dev/null 2>&1 ||
    nft add table "$NFT_FAMILY" "$NFT_TABLE"

nft list set "$NFT_FAMILY" "$NFT_TABLE" n4_killswitch >/dev/null 2>&1 ||
    nft add set "$NFT_FAMILY" "$NFT_TABLE" n4_killswitch \
        '{ type ipv4_addr; flags interval; auto-merge; }'

nft list set "$NFT_FAMILY" "$NFT_TABLE" n6_killswitch >/dev/null 2>&1 ||
    nft add set "$NFT_FAMILY" "$NFT_TABLE" n6_killswitch \
        '{ type ipv6_addr; flags interval; auto-merge; }'

# Update both sets in one nftables transaction. This avoids a period in which
# only some of the configured prefixes are present.
printf -v V4_ELEMENTS '%s, ' "${V4[@]}"
V4_ELEMENTS="${V4_ELEMENTS%, }"

printf -v V6_ELEMENTS '%s, ' "${V6[@]}"
V6_ELEMENTS="${V6_ELEMENTS%, }"

nft -f - <<EOF
flush set $NFT_FAMILY $NFT_TABLE n4_killswitch
add element $NFT_FAMILY $NFT_TABLE n4_killswitch { $V4_ELEMENTS }

flush set $NFT_FAMILY $NFT_TABLE n6_killswitch
add element $NFT_FAMILY $NFT_TABLE n6_killswitch { $V6_ELEMENTS }
EOF

# ---------------------------------------------------------------------------
# nftables chains
# ---------------------------------------------------------------------------

# Mark protected destinations before the existing vpnsplit output chain
# (shown configuration: priority -150).
nft list chain "$NFT_FAMILY" "$NFT_TABLE" mark_output >/dev/null 2>&1 ||
    nft add chain "$NFT_FAMILY" "$NFT_TABLE" mark_output \
        '{ type route hook output priority -151; policy accept; }'

# Check the already-selected egress interface after route selection.
nft list chain "$NFT_FAMILY" "$NFT_TABLE" guard_output >/dev/null 2>&1 ||
    nft add chain "$NFT_FAMILY" "$NFT_TABLE" guard_output \
        '{ type filter hook output priority 0; policy accept; }'

# Replace rules in our two chains atomically.
nft -f - <<EOF
flush chain $NFT_FAMILY $NFT_TABLE mark_output
add rule $NFT_FAMILY $NFT_TABLE mark_output ip daddr @n4_killswitch counter meta mark set $MARK
add rule $NFT_FAMILY $NFT_TABLE mark_output ip6 daddr @n6_killswitch counter meta mark set $MARK

flush chain $NFT_FAMILY $NFT_TABLE guard_output
add rule $NFT_FAMILY $NFT_TABLE guard_output oifname != "$IF" ip daddr @n4_killswitch counter drop
add rule $NFT_FAMILY $NFT_TABLE guard_output oifname != "$IF" ip6 daddr @n6_killswitch counter drop
EOF

# Only now remove the old combined chain: the replacement chains are active.
if nft list chain "$NFT_FAMILY" "$NFT_TABLE" output >/dev/null 2>&1; then
    nft delete chain "$NFT_FAMILY" "$NFT_TABLE" output
fi

# ---------------------------------------------------------------------------
# Policy routing: mark 0x7199 -> table 7199
# ---------------------------------------------------------------------------

# Install the fail-closed route first. It remains if amn0 is absent/deleted.
ip -4 route replace unreachable default table "$TABLE" metric 32767
ip -6 route replace unreachable default table "$TABLE" metric 32767

# Add the preferred route only when the interface exists.
# If amn0 is deleted later, the kernel removes these device routes while the
# unreachable defaults remain in table 7199.
if ip link show dev "$IF" >/dev/null 2>&1; then
    ip -4 route replace default dev "$IF" table "$TABLE" metric 10
    ip -6 route replace default dev "$IF" table "$TABLE" metric 10
else
    echo "WARNING: $IF does not exist; protected traffic will be blocked until the script is run again after $IF is created." >&2
fi

# Replace only our exact rule. Do not delete or modify other priority-1 rules,
# other fwmarks, or any rules/tables belonging to the other VPN programs.
while ip -4 rule del priority "$RULE_PRIORITY" fwmark "$MARK" lookup "$TABLE" 2>/dev/null; do
    :
done
while ip -6 rule del priority "$RULE_PRIORITY" fwmark "$MARK" lookup "$TABLE" 2>/dev/null; do
    :
done

ip -4 rule add priority "$RULE_PRIORITY" fwmark "$MARK" lookup "$TABLE"
ip -6 rule add priority "$RULE_PRIORITY" fwmark "$MARK" lookup "$TABLE"

echo "Selective Kill Switch configured: mark=$MARK table=$TABLE interface=$IF"
