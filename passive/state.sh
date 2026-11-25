#!/bin/bash
echo '=== NFT MARK CHAIN ==='
sudo nft list chain inet killswitch mark_output

echo '=== NFT GUARD CHAIN ==='
sudo nft list chain inet killswitch guard_output

echo '=== IPv4 RULE ==='
ip -4 rule show

echo '=== IPv6 RULE ==='
ip -6 rule show

echo '=== IPv4 TABLE 7199 ==='
ip -4 route show table 7199

echo '=== IPv6 TABLE 7199 ==='
ip -6 route show table 7199

## Expected
# - mark_output: type route hook output priority -151.
# - guard_output: type filter hook output priority 0.
# - В обоих ip rule присутствует fwmark 0x7199 lookup 7199 с приоритетом 1.
# - При работающем amn0 в таблицах 7199 есть маршрут через него и unreachable default.