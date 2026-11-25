#!/bin/bash
ip -4 route show table 7199
ip -6 route show table 7199

## Expected
# unreachable default metric 32767