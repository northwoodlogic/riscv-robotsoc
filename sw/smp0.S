#ifndef AUXSTACK
#define AUXSTACK -2048
#endif

#define HART_ADDRESS 0x400002

.section .init, "ax"
.global _start
_start:
    .cfi_startproc
    .cfi_undefined ra
    .option push
    .option norelax
    la gp, __global_pointer$
    .option pop
    /* Load processor ID address to a1, and the ID value into a0 */
    lui  a1,     %hi(HART_ADDRESS)
    addi a1, a1, %lo(HART_ADDRESS)
    lb   a0,       0(a1)
    la   sp,      __stack_top

    /* If this processor ID == 1, then don't adjust the stack pointer */
    addi t0, zero, 1
    beq  a0,   t0, setfp
    addi sp,   sp, AUXSTACK
setfp:
    add  s0,   sp, zero
    jal zero, main
    .cfi_endproc
    .end
