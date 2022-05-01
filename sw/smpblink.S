/*
 * LED Blinker used for testing SMP system. This loads the hart id from a
 * non-standard memory mapped location and uses the value along with the
 * hardware based xor gpio toggler to blink a led. Each CPU core toggles a
 * different LED. The loader program can start up one or both cores.
 *
 * Load CPU0:
 *   load-bin.sh 0 smpblink.bin
 * Load CPU1:
 *   load-bin.sh 1 smpblink.bin
 * Load Both:
 *   load-bin.sh a smpblink.bin
 *
 * The delay loop code is derived from the SERV blinky.S demo.
 */

.section .init, "ax"
.globl _start
.equ GPIO_BASE, 0x400019
.equ HART_BASE, 0x400002

_start:
    .cfi_startproc
    .cfi_undefined ra
    .option push
    .option norelax
    la gp, __global_pointer$
    .option pop

    /* Load GPIO XOR address to a0 */
    lui a0, %hi(GPIO_BASE)
    addi a0, a0, %lo(GPIO_BASE)

    /* Load HART ID address to a1 */
    lui a1, %hi(HART_BASE)
    addi a1, a1, %lo(HART_BASE)

    /* Load HART ID value into t0 */
    lb t0, 0(a1)

    /* Set timer value to control blink speed */
    li t1, 0x10000

bl1:
    /* store byte / toggle LEDs */
    sb t0, 0(a0)

    /* Reset timer */
    and t2, zero, zero

    /* Delay loop */
time1:
    addi t2, t2, 1
    bne t1, t2, time1
    j bl1

    .cfi_endproc
    .end


