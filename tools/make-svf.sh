#!/bin/sh

/usr/local/diamond/3.12/bin/lin64/ddtcmd -oft -svfsingle \
	-if brevia/riscv_robotsoc_brevia.jed \
	-dev LFXP2-5E -op "SRAM Program,Verify" \
	-runtest -of robotsoc.svf

/usr/local/diamond/3.12/bin/lin64/ddtcmd -oft -svfsingle \
	-if brevia/riscv_robotsoc_brevia.jed \
	-dev LFXP2-5E -op "FLASH Erase,Program,Verify" \
	-runtest -reset -of flash-robotsoc.svf
