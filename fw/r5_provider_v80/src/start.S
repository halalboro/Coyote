/*
 * Coyote Example 15 — R5-0 co-processor provider: minimal bare-metal entry.
 *
 * No MMU, no caches, no BSP. The PLM hands off here after loading this ELF as a
 * delay_handoff psv_cortexr5_0 partition in the combine PDI. Cortex-R5 (ARMv7-R)
 * starts in Supervisor mode; we set the stack, zero .bss, and call main().
 *
 * .text.start is placed at ATCM origin (0x0) so _start is the reset vector.
 */
    .section .text.start, "ax"
    .arm
    .global _start
_start:
    /* Supervisor stack */
    ldr     sp, =__stack_top

    /* Zero .bss */
    ldr     r0, =__bss_start
    ldr     r1, =__bss_end
    mov     r2, #0
1:  cmp     r0, r1
    bhs     2f
    str     r2, [r0], #4
    b       1b

2:  bl      main

3:  wfe
    b       3b
