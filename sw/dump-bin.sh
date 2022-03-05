#!/bin/sh

./robotsoc-io -a 0x100000 -d 0x00000001
./robotsoc-io -r $1

# This causes the program to restart
./robotsoc-io -a 0x100000 -d 0x00000000
