/* A72 first light: lives in OCM at 0xFFFC_1000..0xFFFD_0000 (60 KB).
 *
 * 0xFFFC_0000..0xFFFC_1000 is deliberately left unused: with the toolchain's
 * default 64 KB max-page-size the LOAD segment back-aligns onto it. Build with
 * -Wl,-z,max-page-size=4096 (see build.sh).
 *
 * The handshake block at 0xFFFD_0000 sits outside this region on purpose, so the
 * R5 reads a fixed address that does not move when the app grows. TF-A BL31 will
 * later occupy 0xFFFE_0000..0xFFFF_F000, and the vFPGA ocm_mbx mailbox owns
 * 0xFFFF_F000..0xFFFF_FFFF -- neither may be touched.
 */
ENTRY(_start)

MEMORY
{
    OCM_APP (rwx) : ORIGIN = 0xFFFC1000, LENGTH = 0xF000   /* 60 KB */
}

SECTIONS
{
    .text : {
        KEEP(*(.text.start))
        *(.text*)
        *(.rodata*)
    } > OCM_APP

    .data : { *(.data*) } > OCM_APP

    .bss (NOLOAD) : {
        . = ALIGN(8);
        __bss_start = .;
        *(.bss*) *(COMMON)
        . = ALIGN(8);
        __bss_end = .;
    } > OCM_APP

    . = ALIGN(16);
    __stack_top = ORIGIN(OCM_APP) + LENGTH(OCM_APP) - 16;

    /DISCARD/ : { *(.note.*) *(.comment) *(.eh_frame*) }
}
