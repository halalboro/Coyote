/* Coyote Example 15 — R5-0 provider firmware memory map.
 *
 * Matches the platform contract (cmake/FindCoyoteHW.cmake):
 *   ATCM  0x00000000 .. 0x00010000  (64 KB) — code + data
 *   BTCM  0x00020000 .. 0x00030000  (64 KB) — stack
 * The provider transport MMIO window (0x80010000, see provider_transport_r5.c)
 * and the R5 scratch (0x80000000) are external and NOT part of this image.
 *
 * NOTE: validate against the platform's actual TCM grant when a static build
 * has produced platform/cyt_top.xsa. Build with -Wl,-z,max-page-size=4096.
 */
ENTRY(_start)

MEMORY
{
    ATCM (rwx) : ORIGIN = 0x00000000, LENGTH = 0x00010000   /* 64 KB */
    BTCM (rwx) : ORIGIN = 0x00020000, LENGTH = 0x00010000   /* 64 KB */
}

SECTIONS
{
    .text : {
        KEEP(*(.text.start))
        *(.text*)
        *(.rodata*)
    } > ATCM

    .data : { *(.data*) } > ATCM

    .bss (NOLOAD) : {
        . = ALIGN(8);
        __bss_start = .;
        *(.bss*) *(COMMON)
        . = ALIGN(8);
        __bss_end = .;
    } > ATCM

    . = ALIGN(16);
    __stack_top = ORIGIN(BTCM) + LENGTH(BTCM) - 16;

    /DISCARD/ : { *(.note.*) *(.comment) *(.eh_frame*) *(.ARM.exidx*) }
}
