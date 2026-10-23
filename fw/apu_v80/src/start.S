/**
 * Coyote A72 first light (phase A0) -- minimal EL3 bare-metal entry.
 *
 * No MMU, no caches, no BSP. The PLM hands off here after loading this ELF as a
 * delay_handoff a72-0 partition in the combine PDI.
 */
    .section .text.start, "ax"
    .global _start
_start:
    /* Park every core except A72-0 (MPIDR_EL1.Aff0 == 0). */
    mrs     x0, mpidr_el1
    and     x0, x0, #0xFF
    cbz     x0, 1f
0:  wfe
    b       0b

1:  /* Zero .bss before entering C. Nothing lives there today, but a future
       global would otherwise start with whatever the PLM left in OCM. */
    ldr     x1, =__bss_start
    ldr     x2, =__bss_end
2:  cmp     x1, x2
    b.hs    3f
    str     xzr, [x1], #8
    b       2b

3:  ldr     x0, =__stack_top
    mov     sp, x0
    bl      apu_main

4:  wfe
    b       4b
