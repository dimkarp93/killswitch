#!/bin/bash
sudo -v || exit 1
trap 'kill $(jobs -pr) 2>/dev/null; wait' EXIT INT TERM
for i in cscotun0 tun0 wlo1 enp5s0; do
    sudo tcpdump -l -n -i "$i" 'dst host 160.79.104.1 and icmp' 2>&1 | sed -u "s/^/[$i] /" &
done
wait