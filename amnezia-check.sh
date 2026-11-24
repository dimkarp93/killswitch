#!/bin/bash
ip -4 route get 160.79.104.1
ip -6 route get 2607:6bc0::1

tcpdump -ni amn0 host 160.79.104.1
