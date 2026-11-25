#!/bin/bash
tcpdump -ni amn0 'dst host 2607:6bc0::1 and icmp'