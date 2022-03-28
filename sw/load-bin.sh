#!/bin/sh
cpumask="0x00000002"

case $1 in
    0)
        # hold CPU1 in reset
        cpumask="0x00000002"
        ;;
    1)
        # hold CPU0 in reset
        cpumask="0x00000001"
        ;;
    a)
        # hold no CPU in reset
        cpumask="0x00000000"
        ;;
    *)
        echo "usage:"
        echo " $0 [0|1|a] image.bin"
        echo ""
        echo "invalid boot cpu specificed"
        echo "  specify one of"
        echo "  0 - boot CPU 0"
        echo "  1 - boot CPU 1"
        echo "  a - boot both CPUs"
        exit 1
        ;;
esac

./robotsoc-io -a 0x100000 -d 0x00000003
./robotsoc-io -l $2
if [ "$?" != "0" ] ; then
    exit $?
fi
./robotsoc-io -a 0x100000 -d $cpumask

