#!/bin/sh

# Dump all memory while CPU is runing.
./robotsoc-io -r /tmp/dump.bin 
hexdump -C /tmp/dump.bin

