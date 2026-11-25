#!/bin/bash
sudo tcpdump -ni enp5s0 'dst host 2607:6bc0::1 and icmp'