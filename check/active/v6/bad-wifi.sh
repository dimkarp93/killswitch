#!/bin/bash
sudo tcpdump -ni wlo1 'dst host 2607:6bc0::1 and icmp'