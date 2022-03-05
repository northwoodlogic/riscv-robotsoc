
all : hello.elf

hello.elf: crt0.s hello.c machine.ld
	riscv32-unknown-elf-gcc -g -ffreestanding -O0 -Wl,--gc-sections \
		-nostartfiles  \
		-Wl,-T,machine.ld -Xlinker -Map=hello.map\
		crt0.s hello.c -o hello.elf
	riscv32-unknown-elf-objdump -D hello.elf > hello.asm
	riscv32-unknown-elf-objcopy -O binary hello.elf hello.bin
	riscv32-unknown-elf-size hello.elf

clean :
	- rm *.elf *.bin *.asm *.map
