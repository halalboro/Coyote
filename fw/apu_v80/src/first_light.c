/**
 * Coyote A72 first light (phase A0).
 *
 * Proves the PLM starts an a72-0 partition inside the Coyote combine PDI, and
 * identifies which PS UART reaches the host's /dev/ttyUSB*.
 *
 * The A72 publishes its status STRAIGHT INTO DDR, where the host reads it over
 * PCIe through the driver's MMAP_AMC window. No R5 involvement: the APU has its
 * own path to DDR (FPD_CCI_NOC -> NoC -> DDR4), so nothing has to relay for it.
 * That matters for diagnosis -- if this test fails, the A72 boot itself is the
 * only suspect.
 *
 * A copy also goes to an unused OCM page. Nothing reads it in normal operation;
 * it exists so that if the DDR path is the broken thing, XSDB can still attach
 * over JTAG and see whether the core ran at all.
 *
 * The UART TX FIFOs are written WITHOUT reconfiguring the baud generators, so
 * this inherits whatever the PLM already set up and cannot disturb any other
 * owner of those ports.
 *
 * See docs/superpowers/specs/2026-08-18-a72-linux-vfpga-design.md
 */
#include <stdint.h>

/* Primary: DDR status block, inside the 64 MB host PCIe window (which maps DDR
 * 0x0..0x0400_0000). Sits just below Linux's RAM base at 0x0200_0000 and clear
 * of the AMC's shared memory, so it collides with nothing in any config. */
#define STATUS_DDR       0x01FE0000UL
/* Secondary: OCM copy, JTAG-only fallback (see file header). */
#define STATUS_OCM       0xFFFD0000UL
#define STATUS_MAGIC     0xA72F1157UL

/* Word layout, identical at both addresses:
 *   +0x00 magic   +0x04 heartbeat   +0x08 uart0 chars   +0x0C uart1 chars  */
#define ST_MAGIC         0
#define ST_HEARTBEAT     1
#define ST_UART0         2
#define ST_UART1         3

/* Versal PS UARTs are ARM PL011 PrimeCell -- NOT ZynqMP's Cadence xuartps. */
#define UART0_BASE       0xFF000000UL
#define UART1_BASE       0xFF010000UL
#define PL011_DR         0x00
#define PL011_FR         0x18
#define PL011_FR_TXFF    (1U << 5)

static inline void     mmio_w32(uintptr_t a, uint32_t v) { *(volatile uint32_t *)a = v; }
static inline uint32_t mmio_r32(uintptr_t a)             { return *(volatile uint32_t *)a; }

/* Push one byte, bounded so a dead or unclocked UART cannot hang the core. */
static int uart_putc(uintptr_t base, char c)
{
    for (int i = 0; i < 100000; i++) {
        if ((mmio_r32(base + PL011_FR) & PL011_FR_TXFF) == 0) {
            mmio_w32(base + PL011_DR, (uint32_t)(unsigned char)c);
            return 1;
        }
    }
    return 0;
}

static uint32_t uart_puts(uintptr_t base, const char *s)
{
    uint32_t n = 0;
    for (; *s; s++) {
        if (*s == '\n' && !uart_putc(base, '\r')) return n;
        if (!uart_putc(base, *s)) return n;
        n++;
    }
    return n;
}

void apu_main(void)
{
    volatile uint32_t *ddr = (volatile uint32_t *)STATUS_DDR;
    volatile uint32_t *ocm = (volatile uint32_t *)STATUS_OCM;
    const char *banner = "\n[APU] Coyote A72-0 first light: alive\n";
    uint32_t u0, u1;

    /* Banner first: if the DDR write is what hangs, the UART has already told
     * us the core is running. */
    u0 = uart_puts(UART0_BASE, banner);
    u1 = uart_puts(UART1_BASE, banner);

    /* Magic last of the four, so the host can never observe a half-written
     * block: it polls on the magic and only then trusts the other words.
     * The MMU is off, so every access is Device-nGnRnE -- writes go straight to
     * memory in program order and need no cache maintenance. */
    ocm[ST_UART0] = u0; ocm[ST_UART1] = u1; ocm[ST_HEARTBEAT] = 0;
    ocm[ST_MAGIC] = STATUS_MAGIC;

    ddr[ST_UART0] = u0; ddr[ST_UART1] = u1; ddr[ST_HEARTBEAT] = 0;
    ddr[ST_MAGIC] = STATUS_MAGIC;

    for (uint32_t beat = 1; ; beat++) {
        ddr[ST_HEARTBEAT] = beat;
        ocm[ST_HEARTBEAT] = beat;
        /* Only paces the UART chatter; exact duration does not matter. The
         * host distinguishes "running" from "stopped" by reading the heartbeat
         * twice and seeing it advance. */
        for (volatile uint32_t d = 0; d < 20000000U; d++) { }
        if ((beat & 0xF) == 0) {
            uart_puts(UART0_BASE, "[APU] beat\n");
            uart_puts(UART1_BASE, "[APU] beat\n");
        }
    }
}
