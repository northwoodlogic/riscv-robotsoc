#!/bin/sh

./robotsoc-io -a 0x100000 -d 0x00000001
./robotsoc-io -l $1
./robotsoc-io -a 0x100000 -d 0x00000004


