#!/bin/bash
sudo tcpdump -ni enp5s0 'dst host 160.79.104.1 and icmp'