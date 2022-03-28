
all : hello.elf smpblink.elf

hello.elf: crt0.s hello.c machine.ld
	riscv32-unknown-elf-gcc -Wall -g -ffreestanding -O2 -Wl,--gc-sections \
		-nostartfiles  \
		-Wl,-T,machine.ld -Xlinker -Map=hello.map\
		crt0.s hello.c -o hello.elf
	riscv32-unknown-elf-objdump -D hello.elf > hello.asm
	riscv32-unknown-elf-objcopy -O binary hello.elf hello.bin
	riscv32-unknown-elf-size hello.elf

smpblink.elf: smpblink.s machine.ld
	riscv32-unknown-elf-gcc -Wall -g -ffreestanding -O2 -Wl,--gc-sections \
		-nostartfiles  \
		-Wl,-T,machine.ld -Xlinker -Map=smpblink.map\
		smpblink.s -o smpblink.elf
	riscv32-unknown-elf-objdump -D smpblink.elf > smpblink.asm
	riscv32-unknown-elf-objcopy -O binary smpblink.elf smpblink.bin
	riscv32-unknown-elf-size smpblink.elf

clean :
	- rm *.elf *.bin *.asm *.map
