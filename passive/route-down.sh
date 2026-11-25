#!/bin/bash
ip -4 route get 160.79.104.1 mark 0x7199
ip -6 route get 2607:6bc0::1 mark 0x7199

## Expected
# RTNETLINK answers: Network is unreachable