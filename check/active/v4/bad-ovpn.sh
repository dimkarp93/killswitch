#!/bin/bash
sudo tcpdump -ni tun0 'dst host 160.79.104.1 and icmp'