#!/bin/bash
sudo tcpdump -ni cscotun0 'dst host 2607:6bc0::1 and icmp'