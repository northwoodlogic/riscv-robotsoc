
# Add test program names here
BINS = hello smpblink locktest servopwm servopwmscale

# Real targets start here
all : $(addsuffix .bin,$(BINS)) $(addsuffix .asm, $(BINS))

hello.elf: smp0.o hello.o rsio.o
	$(CC) $(LDFLAGS) $^ -o $@

locktest.elf: smp0.o locktest.o rsio.o
	$(CC) $(LDFLAGS) $^ -o $@

servopwm.elf: smp0.o servopwm.o rsio.o
	$(CC) $(LDFLAGS) $^ -o $@

servopwmscale.elf: smp0.o servopwmscale.o rsio.o
	$(CC) $(LDFLAGS) $^ -o $@

smpblink.elf: smpblink.o
	$(CC) $(LDFLAGS) $^ -o $@


clean :
	- rm *.o *.elf *.bin *.asm *.map *.su

# ###########################################################################
# Library stuff

CC      := riscv32-unknown-elf-gcc
SIZE    := riscv32-unknown-elf-size
OBJDUMP := riscv32-unknown-elf-objdump
OBJCOPY := riscv32-unknown-elf-objcopy

# .su files are only generated if -flto is disabled.
CFLAGS += -Wall -g -ffreestanding -ffunction-sections -fdata-sections -fstack-usage
LDFLAGS = -Wl,-gc-sections -nostartfiles -Wl,-T,machine.ld -Xlinker -Map=$@.map -Wl,--print-memory-usage

ifeq ($(WITH_SPINLOCK_PROFILE), 1)
CFLAGS += -DSPINLOCK_PROFILE
endif

ifneq ($(WITHOUT_O2), 1)
CFLAGS += -O2
else
CFLAGS += -O0
endif

# Link time optimization will allow inline of functions across compilation
# units. Inlining can increase code size, but also increase performance.
ifneq ($(WITHOUT_LTO), 1)
CFLAGS += -flto
endif

%.o : %.c
	$(COMPILE.c) $(OUTPUT_OPTION) $<

%.o : %.S
	$(COMPILE.S) $(OUTPUT_OPTION) $<

%.bin : %.elf
	$(OBJCOPY) -O binary $< $@
	$(SIZE) $<

%.asm : %.elf
	$(OBJDUMP) -D $< > $@
