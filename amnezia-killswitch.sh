
#!/bin/bash
set -Eeuo pipefail

[[ $EUID -eq 0 ]] || { echo "Run as root"; exit 1; }

IF="amn0"
TABLE="7199"
MARK="0x7199"
NFT_FAMILY="inet"
NFT_TABLE="killswitch"
CHAIN="output"

# Укажи свои адреса и подсети
V4=("160.79.104.0/23" "153.61.224.0/22")
V6=("2607:6bc0::/48")

# Проверяем интерфейс
ip link show "$IF" >/dev/null || {
    echo "Interface $IF not found"
    exit 1
}

# Создаём отдельную таблицу nftables
nft list table "$NFT_FAMILY" "$NFT_TABLE" >/dev/null 2>&1 ||
    nft add table "$NFT_FAMILY" "$NFT_TABLE"

# Наборы адресов
nft list set inet "$NFT_TABLE" n4_killswitch >/dev/null 2>&1 ||
    nft add set inet "$NFT_TABLE" n4_killswitch \
        '{ type ipv4_addr; flags interval; auto-merge; }'

nft list set inet "$NFT_TABLE" n6_killswitch >/dev/null 2>&1 ||
    nft add set inet "$NFT_TABLE" n6_killswitch \
        '{ type ipv6_addr; flags interval; auto-merge; }'

# Заполняем наборы
for NET in "${V4[@]}"; do
    nft add element inet "$NFT_TABLE" n4_killswitch "{ $NET }" 2>/dev/null || true
done

for NET in "${V6[@]}"; do
    nft add element inet "$NFT_TABLE" n6_killswitch "{ $NET }" 2>/dev/null || true
done

# Создаём отдельную цепочку OUTPUT с высоким приоритетом
nft list chain inet "$NFT_TABLE" "$CHAIN" >/dev/null 2>&1 ||
    nft add chain inet "$NFT_TABLE" "$CHAIN" \
        '{ type filter hook output priority -150; policy accept; }'

# Удаляем старые правила этой таблицы
nft flush chain inet "$NFT_TABLE" "$CHAIN"

# Назначаем метки защищённым пакетам
nft add rule inet "$NFT_TABLE" "$CHAIN" \
    ip daddr @n4_killswitch meta mark set "$MARK"

nft add rule inet "$NFT_TABLE" "$CHAIN" \
    ip6 daddr @n6_killswitch meta mark set "$MARK"

# Запрещаем выход защищённых адресов через другие интерфейсы
nft add rule inet "$NFT_TABLE" "$CHAIN" \
    oifname != "$IF" ip daddr @n4_killswitch drop

nft add rule inet "$NFT_TABLE" "$CHAIN" \
    oifname != "$IF" ip6 daddr @n6_killswitch drop

# Маршруты через Amnezia + защита от fallback
ip -4 route replace default dev "$IF" table "$TABLE" metric 10
ip -4 route replace unreachable default table "$TABLE" metric 32767

ip -6 route replace default dev "$IF" table "$TABLE" metric 10
ip -6 route replace unreachable default table "$TABLE" metric 32767

# Максимальный приоритет после local
ip -4 rule del priority 1 2>/dev/null || true
ip -6 rule del priority 1 2>/dev/null || true

ip -4 rule add priority 1 fwmark "$MARK" lookup "$TABLE"
ip -6 rule add priority 1 fwmark "$MARK" lookup "$TABLE"

echo "Kill Switch configured"
