/**
 * Copyright (c) 2023 - 2025 Advanced Micro Devices, Inc. All rights reserved.
 * SPDX-License-Identifier: MIT
 *
 * This file contains the main entry point for the Alveo Managment Controller
 *
 * @file amc.c
 *
 */

/******************************************************************************/
/* Includes                                                                   */
/******************************************************************************/

/* common includes */
#include "standard.h"
#include "util.h"
#include "amc_cfg.h"
#include "amc_version.h"

/* osal */
#include "osal.h"

/* core_libs */
#include "pll.h"
#include "evl.h"
#include "dal.h"

/* device drivers */
#include "i2c.h"
#include "eeprom.h"
#include "sys_mon.h"
#include "gcq.h"

/* fal */
#include "fw_if_test.h"
#include "fw_if_gcq.h"
#include "fw_if_ospi.h"
#include "fw_if_muxed_device.h"

/* proxy drivers */
#include "axc_proxy_driver.h"
#include "apc_proxy_driver.h"
#include "asc_proxy_driver.h"
#include "ami_proxy_driver.h"
#include "bmc_proxy_driver.h"

/* bim app data */
#include "profile_bim.h"

/* apps */
#include "asdm.h"
#include "in_band_telemetry.h"
#include "out_of_band_telemetry.h"
#include "bim.h"

/* PDR data */
#include "profile_pdr.h"

/* sensor data */
#include "profile_sensors.h"

/* hardware definitions */
#include "profile_hal.h"
#include "profile_fal.h"
#include "profile_muxed_device.h"
#include "profile_debug_menu.h"


/******************************************************************************/
/* Defines                                                                    */
/******************************************************************************/

#define AMC_OUTPUT_LEVEL  ( PLL_OUTPUT_LEVEL_WARNING )
#define AMC_LOGGING_LEVEL ( PLL_OUTPUT_LEVEL_LOGGING )

#define AMC_NAME                      "AMC"

#define AMC_HASH_LEN                  ( 7 )
#define AMC_DATE_LEN                  ( 8 )

#define AMC_TASK_DEFAULT_STACK        ( 0x1000 )
#define AMC_PROXY_NAME_LEN            ( 15 )

#define AMC_TASK_SLEEP_MS             ( 100 )
#define AMC_GET_PROJECT_INFO_SLEEP_MS ( 1000 )

/* ---- Example 15: on-card R5 <-> vFPGA OCM channel self-test --------------- */
/* The vFPGA's ocm_mbx runs a small mailbox in OCM (word offsets below). The R5
 * posts a "+1 over N words" request, the vFPGA reads it over S_AXI_LPD, computes,
 * writes the result back into OCM and bumps V2C_SEQ (also pulses pl_ps_irq1).
 * This exercises the full vFPGA<->R5 OCM path. Base = top 4 KB of OCM
 * (0xFFFC0000 + 0x40000 - 0x1000); OCM is otherwise unused by AMC (lscript.ld). */
#ifndef EN_OCM_SELFTEST
#define EN_OCM_SELFTEST               ( 1 )
#endif
#define OCM_MBX_BASE                  ( 0xFFFFF000u )
#define OCM_OFF_C2V_SEQ               ( 0x00 )   /* R5   -> vFPGA doorbell         */
#define OCM_OFF_OPCODE                ( 0x04 )   /* R5   : 0 PING 1 INC 2 ADD 3 SUM*/
#define OCM_OFF_N_WORDS               ( 0x08 )   /* R5   : payload length          */
#define OCM_OFF_OPERAND               ( 0x0C )   /* R5   : scalar for ADD          */
#define OCM_OFF_V2C_SEQ               ( 0x10 )   /* vFPGA: = C2V_SEQ when done      */
#define OCM_OFF_RCODE                 ( 0x14 )   /* vFPGA: 0 ok, 1 bad op, 2 big    */
#define OCM_OFF_OUT_WORDS             ( 0x18 )   /* vFPGA: words produced           */
#define OCM_OFF_DATA                  ( 0x40 )   /* both : data window              */
#define OCM_OP_PING                   ( 0 )
#define OCM_OP_INC                    ( 1 )
#define OCM_OP_ADD                    ( 2 )
#define OCM_OP_SUM                    ( 3 )
#define OCM_MAX_WORDS                 ( 32 )        /* must match ocm_mbx N_DATA    */
#define OCM_WAIT_ITERS                ( 1000000u )  /* per-attempt spin on V2C_SEQ  */
#define OCM_RETRIES                   ( 4 )         /* retry a timed-out submit     */
#define OCM_WARMUP_MAX                ( 400 )       /* startup pings until channel up*/
#define OCM_LAT_RUNS                  ( 64 )        /* round-trips for latency stats*/
#define OCM_R5_MHZ                    ( 400 )       /* RPU clock for cyc->ns (approx)*/
/* Compact verdict mirror for the host, in the AMC DDR window (BAR4 + AMC_DDR_OFFS
 * + this offset; see driver/include/coyote_defs.h). Clear of AMC's shared mem
 * @0x100000, and inside the window for both the 32 MB (EN_APU=0) and 256 MB
 * (EN_APU=1) variants. */
#define OCM_VERDICT_DDR               ( 0x01FF0000u )
#define OCM_VERDICT_MAGIC             ( 0x4F434D54u )   /* "OCMT" */

/* ---- Phase A0: mirror the A72 (APU) first-light handshake to the host ------ */
/* The APU runs fw/apu_v80 out of OCM and publishes a magic + heartbeat at
 * APU_HANDSHAKE_BASE. The host cannot see OCM (it is not in any BAR window), so
 * the R5 -- which reaches OCM natively -- samples it and mirrors it into the DDR
 * window the host already maps via the driver's MMAP_AMC region.
 *
 * Unlike the abandoned phase-1a axi_ctrl experiment, these reads cannot hang the
 * core: OCM is R5-native LPD memory, not a route through the shell fabric.
 * See docs/superpowers/specs/2026-08-18-a72-linux-vfpga-design.md */
#ifndef EN_APU_FIRST_LIGHT_MIRROR
#define EN_APU_FIRST_LIGHT_MIRROR     ( 1 )
#endif
#define APU_HANDSHAKE_BASE            ( 0xFFFD0000u )
#define APU_HANDSHAKE_MAGIC           ( 0xA72F1157u )
#define APU_OFF_MAGIC                 ( 0x00 )   /* APU: 0xA72F1157 once alive     */
#define APU_OFF_BEAT                  ( 0x04 )   /* APU: free-running heartbeat    */
#define APU_OFF_UART0                 ( 0x08 )   /* APU: chars accepted by UART0   */
#define APU_OFF_UART1                 ( 0x0C )   /* APU: chars accepted by UART1   */
#define APU_SAMPLE_GAP_ITERS          ( 20000000u ) /* spin between beat samples   */
/* Verdict mirror, 64 KB below the OCM one, same DDR window. */
#define APU_VERDICT_DDR               ( 0x01FE0000u )
#define APU_VERDICT_MAGIC             ( 0x41505521u )   /* "APU!" */


/******************************************************************************/
/* Enums                                                                      */
/******************************************************************************/

/**
 * @enum    AMC_TASK_PRIOS
 * @brief   AMC Task priorities
 */
typedef enum AMC_TASK_PRIOS
{
    AMC_TASK_PRIO_RSVD = 5, /* TODO: get actual value from osal.h */

    AMC_TASK_PRIO_DEFAULT,
    MAX_AMC_TASK_PRIO

} AMC_TASK_PRIOS;


/******************************************************************************/
/* EVL Callback Declarations                                                  */
/******************************************************************************/

/**
 * @brief   EVL Callbacks for binding to Proxy Drivers
 *
 * @param   pxSignal     Event raised
 *
 * @return  OK if no errors were raised in the callback
 *          ERROR if an error was raised in the callback
 *
 */
static int iApcCallback( EVL_SIGNAL *pxSignal );
static int iAmiCallback( EVL_SIGNAL *pxSignal );
static int iAxcCallback( EVL_SIGNAL *pxSignal );
static int iBmcCallback( EVL_SIGNAL *pxSignal );


/******************************************************************************/
/* Local Function Declarations                                                */
/******************************************************************************/

/**
 * @brief   Get project info
 *
 * @return  N/A
 *
 */
static void vGetProjectInfo( void );

/**
 * @brief   Initialise core libraries
 *
 * @return  OK if all core libraries initialised successfully
 *          ERROR if any or all core libraries not initialised
 *
 */
static int iInitCoreLibs( void );

/**
 * @brief   Initialise device drivers
 *
 * @return  OK if all device drivers initialised and created successfully
 *          ERROR if any or all device drivers not initialised
 *
 */
static int iInitDeviceDrivers( void );

/**
 * @brief   Initialise Proxy Driver layer
 *
 * @return  OK if all Proxy Drivers initialised and bound successfully
 *          ERROR if any or all proxy drivers not initialised
 *
 */
static int iInitProxies( void );

/**
 * @brief   Initialise App layer
 *
 * @return  OK if all Apps initialised and created successfully
 *          ERROR if any or all apps not initialised
 *
 */
static int iInitApp( void );

/**
 * @brief   Initialise Debug monitoring
 *
 * @return  OK if debug initialised (or if debug disabled)
 *          ERROR if debug enabled but did not initialise
 */
static int iInitDebug( void );

/**
 * @brief   The main task that init the FAL & proxy drivers
 *
 * @return  N/A
 */
static void vTaskFuncMain( void );

#if ( 1 == EN_OCM_SELFTEST )
/**
 * @brief   Exercise the vFPGA<->R5 OCM channel once and record a verdict.
 * @return  N/A
 */
static void vOcmSelfTest( void );
#endif

#if ( 1 == EN_APU_FIRST_LIGHT_MIRROR )
/**
 * @brief   Sample the A72 first-light handshake in OCM and mirror it to DDR
 *          so the host can observe whether the APU booted and is running.
 * @return  N/A
 */
static void vApuFirstLightMirror( void );
#endif

/**
 * @brief   Configure the partition table stored at the start of
 *          shared memory and used by the AMI to deremine the AMC state
 * @return  N/A
 */
static void vConfigurePartitionTable( void );


/******************************************************************************/
/* Local variables                                                            */
/******************************************************************************/

/* Note: the default I2C clock frequency isn't used */
static I2C_CFG_TYPE xI2cCfg[ I2C_NUM_INSTANCES ] =
{ {
    HAL_I2C_BUS_0_DEVICE_ID,
    ( uint64_t )HAL_I2C_BUS_0_BASEADDR,
    HAL_I2C_BUS_0_I2C_CLK_FREQ_HZ,
    HAL_I2C_RETRY_COUNT,
    HAL_I2C_BUS_0_SW_RESET_OFFSET,
    HAL_I2C_BUS_0_RESET_ON_INIT,
    HAL_I2C_BUS_0_HW_RESET_ADDR,
    HAL_I2C_BUS_0_HW_RESET_MASK,
    HAL_I2C_BUS_0_HW_DEVICE_RESET
  },
  {
    HAL_I2C_BUS_1_DEVICE_ID,
    ( uint64_t )HAL_I2C_BUS_1_BASEADDR,
    HAL_I2C_BUS_1_I2C_CLK_FREQ_HZ,
    HAL_I2C_RETRY_COUNT,
    HAL_I2C_BUS_1_SW_RESET_OFFSET,
    HAL_I2C_BUS_1_RESET_ON_INIT,
    HAL_I2C_BUS_1_HW_RESET_ADDR,
    HAL_I2C_BUS_1_HW_RESET_MASK,
    HAL_I2C_BUS_1_HW_DEVICE_RESET
  } };

static EEPROM_CFG xEepromCfg =
{
    HAL_EEPROM_I2C_BUS,
    HAL_EEPROM_SLAVE_ADDRESS,
    HAL_EEPROM_ADDRESS_SIZE,
    HAL_EEPROM_PAGE_SIZE,
    HAL_EEPROM_NUM_PAGES,
    HAL_EEPROM_DEVICE_ID_ADDRESS,
    HAL_EEPROM_DEVICE_ID_REGISTER,
    HAL_EEPROM_DEVICE_ID
};

/* AXC External Device configs */
AXC_PROXY_DRIVER_EXTERNAL_DEVICE_CONFIG xQsfpDevice1 =
{
    &xQsfpIf1, 0
};
AXC_PROXY_DRIVER_EXTERNAL_DEVICE_CONFIG xQsfpDevice2 =
{
    &xQsfpIf2, 1
};
AXC_PROXY_DRIVER_EXTERNAL_DEVICE_CONFIG xQsfpDevice3 =
{
    &xQsfpIf3, 2
};
AXC_PROXY_DRIVER_EXTERNAL_DEVICE_CONFIG xQsfpDevice4 =
{
    &xQsfpIf4, 3
};
AXC_PROXY_DRIVER_EXTERNAL_DEVICE_CONFIG xDimmDevice =
{
    &xDimmIf, 4
};

uint64_t ullAmcInitStatus = 0;


/******************************************************************************/
/* Function implementations                                                   */
/******************************************************************************/

/*
 * @brief   The main task
 */
static void vTaskFuncMain( void )
{
    int iStatus = ERROR;

    vConfigurePartitionTable();

    if( OK == iInitCoreLibs() )
    {
        PLL_LOG( AMC_NAME, "Core Libs initialised OK\r\n" );
        iStatus = OK;
    }
    else
    {
        PLL_LOG( AMC_NAME, "Core Libs initialisation ERROR\t\n" );
    }

    if( OK == iInitDeviceDrivers() )
    {
        PLL_LOG( AMC_NAME, "Device drivers Initialised OK\r\n" );
        iStatus = OK;
    }
    else
    {
        PLL_LOG( AMC_NAME, "Device drivers Initialisation ERROR\r\n" );
    }

    if( OK == iFAL_Initialise( &ullAmcInitStatus ) )
    {
        PLL_LOG( AMC_NAME, "FAL Initialised OK\r\n" );
    }
    else
    {
        PLL_LOG( AMC_NAME, "FAL Initialisation ERROR\r\n" );
    }

    if( OK == iInitProxies() )
    {
        PLL_LOG( AMC_NAME, "Proxy Drivers Initialised OK\r\n" );
        iStatus = OK;
    }
    else
    {
        PLL_LOG( AMC_NAME, "Proxy Drivers Initialisation ERROR\r\n" );
    }

    if( OK == iInitApp() )
    {
        PLL_LOG( AMC_NAME, "Apps Initialised OK\r\n" );
    }
    else
    {
        PLL_LOG( AMC_NAME, "Apps Initialisation ERROR\r\n" );
        iStatus = ERROR;
    }

    /* always initialise debug interface (if enabled) */
    if( OK != iInitDebug() )
    {
        PLL_ERR( AMC_NAME, "Debug access initialisation error\r\n" );
    }

    if( ERROR == iStatus )
    {
        /*
         * The final step before starting the main task is to configure the start
         * of the shared memory with the information needed by the AMI.
         */
        PLL_ERR( AMC_NAME, "Error Main Task has initialisation failures\r\n" );
    }

    PLL_INF( AMC_NAME, "ullAmcInitStatus:\n\r" );
    PLL_INF( AMC_NAME,
             "ucPllInitialised                %s\n\r",
             ( ullAmcInitStatus & AMC_CFG_PLL_INITIALISED            ? "TRUE" : "FALSE" ) );
    PLL_INF( AMC_NAME,
             "ucEvlInitialised                %s\n\r",
             ( ullAmcInitStatus & AMC_CFG_EVL_INITIALISED            ? "TRUE" : "FALSE" ) );
    PLL_INF( AMC_NAME,
             "ucI2cInitialised                %s\n\r",
             ( ullAmcInitStatus & AMC_CFG_I2C_INITIALISED            ? "TRUE" : "FALSE" ) );
    PLL_INF( AMC_NAME,
             "ucEepromInitialised             %s\n\r",
             ( ullAmcInitStatus & AMC_CFG_EEPROM_INITIALISED         ? "TRUE" : "FALSE" ) );
    PLL_INF( AMC_NAME,
             "ucSysmonInitialised             %s\n\r",
             ( ullAmcInitStatus & AMC_CFG_SYSMON_INITIALISED         ? "TRUE" : "FALSE" ) );
    PLL_INF( AMC_NAME,
             "ucSmbusPcieLinkInitialised      %s\n\r",
             ( ullAmcInitStatus & AMC_CFG_SMBUS_PCIE_LINK_INITIALISED  ? "TRUE" : "FALSE" ) );
    PLL_INF( AMC_NAME,
             "ucMuxedDeviceFalInitialised     %s\n\r",
             ( ullAmcInitStatus & AMC_CFG_MUXED_DEVICE_FAL_INITIALISED ? "TRUE" : "FALSE" ) );
    PLL_INF( AMC_NAME,
             "ucGcqFalInitialised             %s\n\r",
             ( ullAmcInitStatus & AMC_CFG_MUXED_DEVICE_FAL_CREATED         ? "TRUE" : "FALSE" ) );
    PLL_INF( AMC_NAME,
             "ucEmmcFalInitialised            %s\n\r",
             ( ullAmcInitStatus & AMC_CFG_GCQ_FAL_INITIALISED        ? "TRUE" : "FALSE" ) );
    PLL_INF( AMC_NAME,
             "ucOspiFalInitialised            %s\n\r",
             ( ullAmcInitStatus & AMC_CFG_GCQ_FAL_CREATED        ? "TRUE" : "FALSE" ) );
    PLL_INF( AMC_NAME,
             "ucSmbusFalInitialised           %s\n\r",
             ( ullAmcInitStatus & AMC_CFG_EMMC_FAL_INITIALISED       ? "TRUE" : "FALSE" ) );
    PLL_INF( AMC_NAME,
             "ucMuxedDeviceFalCreated         %s\n\r",
             ( ullAmcInitStatus & AMC_CFG_EMMC_FAL_CREATED     ? "TRUE" : "FALSE" ) );
    PLL_INF( AMC_NAME,
             "ucGcqFalCreated                 %s\n\r",
             ( ullAmcInitStatus & AMC_CFG_OSPI_FAL_INITIALISED             ? "TRUE" : "FALSE" ) );
    PLL_INF( AMC_NAME,
             "ucEmmcFalCreated                %s\n\r",
             ( ullAmcInitStatus & AMC_CFG_OSPI_FAL_CREATED            ? "TRUE" : "FALSE" ) );
    PLL_INF( AMC_NAME,
             "ucOspiFalCreated                %s\n\r",
             ( ullAmcInitStatus & AMC_CFG_SMBUS_FAL_INITIALISED            ? "TRUE" : "FALSE" ) );
    PLL_INF( AMC_NAME,
             "ucSmbusFalCreated               %s\n\r",
             ( ullAmcInitStatus & AMC_CFG_SMBUS_FAL_CREATED           ? "TRUE" : "FALSE" ) );
    PLL_INF( AMC_NAME,
             "ucApcInitialised                %s\n\r",
             ( ullAmcInitStatus & AMC_CFG_APC_INITIALISED            ? "TRUE" : "FALSE" ) );
    PLL_INF( AMC_NAME,
             "ucAxcInitialised                %s\n\r",
             ( ullAmcInitStatus & AMC_CFG_AXC_INITIALISED            ? "TRUE" : "FALSE" ) );
    PLL_INF( AMC_NAME,
             "ucAscInitialised                %s\n\r",
             ( ullAmcInitStatus & AMC_CFG_ASC_INITIALISED            ? "TRUE" : "FALSE" ) );
    PLL_INF( AMC_NAME,
             "ucAmiInitialised                %s\n\r",
             ( ullAmcInitStatus & AMC_CFG_AMI_INITIALISED            ? "TRUE" : "FALSE" ) );
    PLL_INF( AMC_NAME,
             "ucBmcInitialised                %s\n\r",
             ( ullAmcInitStatus & AMC_CFG_BMC_INITIALISED            ? "TRUE" : "FALSE" ) );
    PLL_INF( AMC_NAME,
             "ucAsdmInitialised               %s\n\r",
             ( ullAmcInitStatus & AMC_CFG_ASDM_INITIALISED           ? "TRUE" : "FALSE" ) );
    PLL_INF( AMC_NAME,
             "ucInBandInitialised             %s\n\r",
             ( ullAmcInitStatus & AMC_CFG_IN_BAND_INITIALISED         ? "TRUE" : "FALSE" ) );
    PLL_INF( AMC_NAME,
             "ucOutOfBandInitialised          %s\n\r",
             ( ullAmcInitStatus & AMC_CFG_OUT_OF_BAND_INITIALISED      ? "TRUE" : "FALSE" ) );

#if ( 1 == EN_OCM_SELFTEST )
    /* Once the platform is up, exercise the vFPGA<->R5 OCM channel. */
    vOcmSelfTest();
#endif

#if ( 1 == EN_APU_FIRST_LIGHT_MIRROR )
    /* Report whether the A72 partition booted beside us (phase A0). */
    vApuFirstLightMirror();
#endif

    FOREVER
    {
        iOSAL_Task_SleepMs( AMC_TASK_SLEEP_MS );
    }
}

#if ( 1 == EN_OCM_SELFTEST )
/* Cortex-R5 PMU cycle counter (PMCCNTR) for round-trip latency. R5 runs
 * privileged so the CP15 PMU registers are accessible. */
static inline void ocm_ccnt_init( void )
{
    uint32_t v;
    __asm volatile( "mrc p15, 0, %0, c9, c12, 0" : "=r"( v ) );  /* PMCR      */
    v |= ( 1u << 0 ) | ( 1u << 2 );                              /* enable+reset */
    __asm volatile( "mcr p15, 0, %0, c9, c12, 0" :: "r"( v ) );
    __asm volatile( "mcr p15, 0, %0, c9, c12, 1" :: "r"( 1u << 31 ) ); /* PMCNTENSET: CCNT */
}
static inline uint32_t ocm_ccnt( void )
{
    uint32_t v;
    __asm volatile( "mrc p15, 0, %0, c9, c13, 0" : "=r"( v ) );  /* PMCCNTR */
    return v;
}

/**
 * @brief   Submit one command over the OCM mailbox and wait for completion.
 *
 * Seeds the data window + command, rings the doorbell, and spins on V2C_SEQ.
 * Retries a timed-out submit up to OCM_RETRIES (hardens the first-transaction-
 * after-boot edge). Reports round-trip cost in R5 cycles and in poll iterations.
 *
 * @return  vFPGA RCODE, or 0xFFFFFFFF if every attempt timed out.
 */
static uint32_t ocm_submit( uint32_t opcode, uint32_t operand,
                            const uint32_t *in, uint32_t n,
                            uint32_t *out, uint32_t *out_n,
                            uint32_t *cycles, uint32_t *iters, uint32_t *retries )
{
    uint32_t attempt, i, seq = 0, v2c = 0, it = 0, c0 = 0, c1 = 0;

    for( attempt = 0; attempt < OCM_RETRIES; attempt++ )
    {
        /* (Re)seed each attempt so a partially-serviced prior try can't corrupt. */
        for( i = 0; i < n && i < OCM_MAX_WORDS; i++ )
        {
            HAL_IO_WRITE32( in[i], OCM_MBX_BASE + OCM_OFF_DATA + ( i << 2 ) );
        }
        HAL_IO_WRITE32( opcode,  OCM_MBX_BASE + OCM_OFF_OPCODE );
        HAL_IO_WRITE32( n,       OCM_MBX_BASE + OCM_OFF_N_WORDS );
        HAL_IO_WRITE32( operand, OCM_MBX_BASE + OCM_OFF_OPERAND );

        seq = HAL_IO_READ32( OCM_MBX_BASE + OCM_OFF_V2C_SEQ ) + 1u;  /* next unused */
        c0 = ocm_ccnt();
        HAL_IO_WRITE32( seq, OCM_MBX_BASE + OCM_OFF_C2V_SEQ );       /* doorbell */
        for( it = 0; it < OCM_WAIT_ITERS; it++ )
        {
            v2c = HAL_IO_READ32( OCM_MBX_BASE + OCM_OFF_V2C_SEQ );
            if( v2c == seq )
            {
                break;
            }
        }
        c1 = ocm_ccnt();
        if( v2c == seq )
        {
            break;
        }
        if( retries ) { ( *retries )++; }
    }

    if( cycles ) { *cycles = c1 - c0; }
    if( iters )  { *iters  = it; }
    if( v2c != seq ) { return 0xFFFFFFFF; }

    if( out_n ) { *out_n = HAL_IO_READ32( OCM_MBX_BASE + OCM_OFF_OUT_WORDS ); }
    if( out )
    {
        uint32_t on = out_n ? *out_n : 0;
        for( i = 0; i < on && i < OCM_MAX_WORDS; i++ )
        {
            out[i] = HAL_IO_READ32( OCM_MBX_BASE + OCM_OFF_DATA + ( i << 2 ) );
        }
    }
    return HAL_IO_READ32( OCM_MBX_BASE + OCM_OFF_RCODE );
}

/**
 * @brief   Exercise the OCM command ABI (PING/INC/ADD/SUM), measure round-trip
 *          latency, and mirror a verdict to the host-visible AMC DDR window.
 */
static void vOcmSelfTest( void )
{
    uint32_t in[OCM_MAX_WORDS], out[OCM_MAX_WORDS], out_n, rc, i;
    uint32_t passed = 0, first_fail = 0, retries = 0, cyc, it;
    uint32_t lat_min = 0xFFFFFFFF, lat_max = 0, lat_sum = 0, it_min = 0xFFFFFFFF;

    ocm_ccnt_init();
    /* Quiesce the header so power-on garbage can't look like a request. */
    HAL_IO_WRITE32( 0, OCM_MBX_BASE + OCM_OFF_V2C_SEQ );
    HAL_IO_WRITE32( 0, OCM_MBX_BASE + OCM_OFF_C2V_SEQ );

    /* Warm-up handshake: the vFPGA's ocm_mbx blocks on its first S_AXI_LPD read
     * until the CIPS LPD path is up after PS boot (its AXI engine has no timeout).
     * Ping until it answers so the real work runs on a ready channel. */
    uint32_t warmup = 0;
    {
        uint32_t s, jt, v = 0;
        for( warmup = 0; warmup < OCM_WARMUP_MAX; warmup++ )
        {
            s = HAL_IO_READ32( OCM_MBX_BASE + OCM_OFF_V2C_SEQ ) + 1u;
            HAL_IO_WRITE32( OCM_OP_PING, OCM_MBX_BASE + OCM_OFF_OPCODE );
            HAL_IO_WRITE32( 0,           OCM_MBX_BASE + OCM_OFF_N_WORDS );
            HAL_IO_WRITE32( 0,           OCM_MBX_BASE + OCM_OFF_OPERAND );
            HAL_IO_WRITE32( s,           OCM_MBX_BASE + OCM_OFF_C2V_SEQ );
            for( jt = 0; jt < OCM_WAIT_ITERS; jt++ )
            {
                v = HAL_IO_READ32( OCM_MBX_BASE + OCM_OFF_V2C_SEQ );
                if( v == s ) { break; }
            }
            if( v == s ) { break; }
        }
    }
    PLL_LOG( AMC_NAME, "OCM self-test: channel up after %u warm-up pings\r\n", (unsigned) warmup );

    PLL_LOG( AMC_NAME, "OCM self-test: ABI PING/INC/ADD/SUM (mbx @ 0x%08X)\r\n", OCM_MBX_BASE );

    /* 1) PING — liveness, no data window. */
    rc = ocm_submit( OCM_OP_PING, 0, NULL, 0, NULL, &out_n, &cyc, &it, &retries );
    if( rc == 0 && out_n == 0 ) { passed++; } else if( !first_fail ) { first_fail = 1; }

    /* 2) INC — DATA[i] + 1 over 8 words. */
    for( i = 0; i < 8; i++ ) { in[i] = 0x100u + i; }
    rc = ocm_submit( OCM_OP_INC, 0, in, 8, out, &out_n, &cyc, &it, &retries );
    { uint32_t good = ( rc == 0 && out_n == 8 );
      for( i = 0; i < 8; i++ ) { if( out[i] != 0x100u + i + 1u ) { good = 0; } }
      if( good ) { passed++; } else if( !first_fail ) { first_fail = 2; } }

    /* 3) ADD — DATA[i] + operand over 5 words. */
    for( i = 0; i < 5; i++ ) { in[i] = 1000u + i; }
    rc = ocm_submit( OCM_OP_ADD, 7, in, 5, out, &out_n, &cyc, &it, &retries );
    { uint32_t good = ( rc == 0 && out_n == 5 );
      for( i = 0; i < 5; i++ ) { if( out[i] != 1000u + i + 7u ) { good = 0; } }
      if( good ) { passed++; } else if( !first_fail ) { first_fail = 3; } }

    /* 4) SUM — DATA[0] = reduction over 4 words. */
    in[0] = 10; in[1] = 20; in[2] = 30; in[3] = 40;
    rc = ocm_submit( OCM_OP_SUM, 0, in, 4, out, &out_n, &cyc, &it, &retries );
    if( rc == 0 && out_n == 1 && out[0] == 100u ) { passed++; } else if( !first_fail ) { first_fail = 4; }

    /* Latency: repeated PING = channel round-trip floor. */
    for( i = 0; i < OCM_LAT_RUNS; i++ )
    {
        rc = ocm_submit( OCM_OP_PING, 0, in, 0, NULL, NULL, &cyc, &it, &retries );
        if( rc == 0 )
        {
            lat_sum += cyc;
            if( cyc < lat_min ) { lat_min = cyc; }
            if( cyc > lat_max ) { lat_max = cyc; }
            if( it  < it_min  ) { it_min  = it;  }
        }
    }

    PLL_LOG( AMC_NAME, "OCM self-test: %u/4 opcodes OK, %u retries, latency ~%u cyc\r\n",
             (unsigned) passed, (unsigned) retries,
             (unsigned) ( lat_min == 0xFFFFFFFF ? 0 : lat_min ) );

    /* Host-visible verdict (payload first, magic last):
     *   +0x04 passed  +0x08 total(4)  +0x0C first_fail(0=none|opcode id)
     *   +0x10 lat_min_cyc  +0x14 lat_max_cyc  +0x18 lat_avg_cyc
     *   +0x1C retries  +0x20 r5_mhz  +0x24 lat_min_iters */
    HAL_IO_WRITE32( passed,                                OCM_VERDICT_DDR + 0x04 );
    HAL_IO_WRITE32( 4u,                                    OCM_VERDICT_DDR + 0x08 );
    HAL_IO_WRITE32( first_fail,                            OCM_VERDICT_DDR + 0x0C );
    HAL_IO_WRITE32( ( lat_min == 0xFFFFFFFF ? 0 : lat_min ), OCM_VERDICT_DDR + 0x10 );
    HAL_IO_WRITE32( lat_max,                               OCM_VERDICT_DDR + 0x14 );
    HAL_IO_WRITE32( ( OCM_LAT_RUNS ? lat_sum / OCM_LAT_RUNS : 0 ), OCM_VERDICT_DDR + 0x18 );
    HAL_IO_WRITE32( retries,                               OCM_VERDICT_DDR + 0x1C );
    HAL_IO_WRITE32( OCM_R5_MHZ,                            OCM_VERDICT_DDR + 0x20 );
    HAL_IO_WRITE32( ( it_min == 0xFFFFFFFF ? 0 : it_min ), OCM_VERDICT_DDR + 0x24 );
    HAL_IO_WRITE32( warmup,                                OCM_VERDICT_DDR + 0x28 );
    HAL_IO_WRITE32( OCM_VERDICT_MAGIC,                     OCM_VERDICT_DDR + 0x00 );
}
#endif

#if ( 1 == EN_APU_FIRST_LIGHT_MIRROR )
/**
 * @brief   Sample the A72 first-light handshake in OCM and mirror it to DDR.
 *
 * Two heartbeat samples separated by a bounded spin let the host distinguish
 * "the APU booted and is running" from "the APU booted then stopped". A plain
 * spin is used rather than vTaskDelay because this file uses no FreeRTOS delay
 * primitives elsewhere and the exact interval does not matter.
 *
 * @return  N/A
 */
static void vApuFirstLightMirror( void )
{
    uint32_t ulMagic = 0;
    uint32_t ulBeat1 = 0;
    uint32_t ulBeat2 = 0;
    uint32_t ulUart0 = 0;
    uint32_t ulUart1 = 0;
    uint32_t i       = 0;

    ulMagic = HAL_IO_READ32( APU_HANDSHAKE_BASE + APU_OFF_MAGIC );
    ulBeat1 = HAL_IO_READ32( APU_HANDSHAKE_BASE + APU_OFF_BEAT  );
    ulUart0 = HAL_IO_READ32( APU_HANDSHAKE_BASE + APU_OFF_UART0 );
    ulUart1 = HAL_IO_READ32( APU_HANDSHAKE_BASE + APU_OFF_UART1 );

    for( i = 0; i < APU_SAMPLE_GAP_ITERS; i++ )
    {
        __asm__ volatile( "nop" );
    }

    ulBeat2 = HAL_IO_READ32( APU_HANDSHAKE_BASE + APU_OFF_BEAT );

    HAL_IO_WRITE32( APU_VERDICT_MAGIC,                                APU_VERDICT_DDR + 0x00 );
    HAL_IO_WRITE32( ( APU_HANDSHAKE_MAGIC == ulMagic ) ? 1u : 0u,     APU_VERDICT_DDR + 0x04 );
    HAL_IO_WRITE32( ulBeat1,                                          APU_VERDICT_DDR + 0x08 );
    HAL_IO_WRITE32( ulUart0,                                          APU_VERDICT_DDR + 0x0C );
    HAL_IO_WRITE32( ulUart1,                                          APU_VERDICT_DDR + 0x10 );
    HAL_IO_WRITE32( ulBeat2,                                          APU_VERDICT_DDR + 0x14 );

    PLL_LOG( AMC_NAME, "APU first light: magic 0x%08X beat %u->%u uart0 %u uart1 %u\r\n",
             ( unsigned int )ulMagic, ( unsigned int )ulBeat1, ( unsigned int )ulBeat2,
             ( unsigned int )ulUart0, ( unsigned int )ulUart1 );
}
#endif


/**
 * @brief   Main entry point
 */
int main( void )
{
    void *pvMainTaskHandle = NULL;

    if( OSAL_ERRORS_OS_NOT_STARTED != iOSAL_StartOS( TRUE,
                                                     &pvMainTaskHandle,
                                                     &vTaskFuncMain,
                                                     AMC_TASK_DEFAULT_STACK,
                                                     AMC_TASK_PRIO_DEFAULT ) )
    {
        PLL_ERR( AMC_NAME, "Error failed to start the OS Task\r\n" );
    }

    return -1;
}


/******************************************************************************/
/* EVL Callback Implementations                                               */
/******************************************************************************/

/**
 * @brief   AXC Proxy Driver EVL callback
 */
static int iAxcCallback( EVL_SIGNAL *pxSignal )
{
    int iStatus = ERROR;

    if( ( NULL != pxSignal ) && ( AMC_CFG_UNIQUE_ID_AXC == pxSignal->ucModule ) )
    {
        switch( pxSignal->ucEventType )
        {
            case AXC_PROXY_DRIVER_E_QSFP_PRESENT:
                iStatus = OK;
                break;

            case AXC_PROXY_DRIVER_E_QSFP_NOT_PRESENT:
                iStatus = OK;
                break;

            default:
                break;
        }
    }

    return iStatus;
}

/**
 * @brief   APC Proxy Driver EVL callback
 */
static int iApcCallback( EVL_SIGNAL *pxSignal )
{
    int iStatus = ERROR;

    if( ( NULL != pxSignal ) && ( AMC_CFG_UNIQUE_ID_APC == pxSignal->ucModule ) )
    {
        switch( pxSignal->ucEventType )
        {
        case APC_PROXY_DRIVER_E_DOWNLOAD_STARTED:
        {
            iStatus = OK;
            break;
        }

        case APC_PROXY_DRIVER_E_DOWNLOAD_COMPLETE:
        {
            iStatus = iAMI_SetPdiDownloadCompleteResponse( pxSignal, AMI_PROXY_RESULT_SUCCESS );
            break;
        }

        case APC_PROXY_DRIVER_E_DOWNLOAD_FAILED:
        {
            iStatus = iAMI_SetPdiDownloadCompleteResponse( pxSignal, AMI_PROXY_RESULT_FAILURE );
            break;
        }

        case APC_PROXY_DRIVER_E_DOWNLOAD_BUSY:
        {
            iStatus = iAMI_SetPdiDownloadCompleteResponse( pxSignal, AMI_PROXY_RESULT_ALREADY_IN_PROGRESS );
            break;
        }

        case APC_PROXY_DRIVER_E_COPY_STARTED:
        {
            iStatus = OK;
            break;
        }

        case APC_PROXY_DRIVER_E_COPY_COMPLETE:
        {
            iStatus = iAMI_SetPdiCopyCompleteResponse( pxSignal, AMI_PROXY_RESULT_SUCCESS );
            break;
        }

        case APC_PROXY_DRIVER_E_COPY_FAILED:
        {
            iStatus = iAMI_SetPdiCopyCompleteResponse( pxSignal, AMI_PROXY_RESULT_FAILURE );
            break;
        }

        case APC_PROXY_DRIVER_E_COPY_BUSY:
        {
            iStatus = iAMI_SetPdiCopyCompleteResponse( pxSignal, AMI_PROXY_RESULT_ALREADY_IN_PROGRESS );
            break;
        }

        case APC_PROXY_DRIVER_E_PARTITION_SELECTED:
        {
            iStatus = iAMI_SetBootSelectCompleteResponse( pxSignal, AMI_PROXY_RESULT_SUCCESS );
            break;
        }

        case APC_PROXY_DRIVER_E_PARTITION_SELECTION_FAILED:
        {
            iStatus = iAMI_SetBootSelectCompleteResponse( pxSignal, AMI_PROXY_RESULT_FAILURE );
            break;
        }

        default:
        {
            break;
        }
        }
    }

    return iStatus;
}

/**
 * @brief   AMI Proxy Driver EVL callback
 */
static int iAmiCallback( EVL_SIGNAL *pxSignal )
{
    int iStatus = ERROR;

    if( ( NULL != pxSignal ) && ( AMC_CFG_UNIQUE_ID_AMI == pxSignal->ucModule ) )
    {
        switch( pxSignal->ucEventType )
        {
        case AMI_PROXY_DRIVER_E_GET_IDENTITY:
        {
            PLL_DBG( AMC_NAME, "Event Get Identity (0x%02X)\r\n", pxSignal->ucEventType );

            AMI_PROXY_RESULT xResult = AMI_PROXY_RESULT_SUCCESS;

            GCQ_VERSION_TYPE xGcqVersion =
            {
                0
            };
            if( OK != iGCQGetVersion( &xGcqVersion ) )
            {
                PLL_DBG( AMC_NAME, "Error getting GCQ version\r\n" );
                xResult = AMI_PROXY_RESULT_FAILURE;
            }

            AMI_PROXY_IDENTITY_RESPONSE xIdentityResponse =
            {
                .ucVerMajor     = ( uint8_t )GIT_TAG_VER_MAJOR,
                .ucVerMinor     = ( uint8_t )GIT_TAG_VER_MINOR,
                .ucVerPatch     = ( uint8_t )GIT_TAG_VER_PATCH,
                .ucLocalChanges = ( uint8_t )( GIT_STATUS )?( 1 ):( 0 ),
                .usDevCommits   = ( uint16_t )GIT_TAG_VER_DEV_COMMITS,
                .ucLinkVerMajor = xGcqVersion.ucVerMajor,
                .ucLinkVerMinor = xGcqVersion.ucVerMinor
            };
            iStatus = iAMI_SetIdentityResponse( pxSignal, xResult, &xIdentityResponse );

            /* AMI is ready - enable hot reset */
            if( OK == iAPC_EnableHotReset( pxSignal ) )
            {
                PLL_DBG( AMC_NAME, "Hot reset enabled\r\n" );
            }

            if( OK == iPLL_SendBootRecords() )
            {
                PLL_INF( AMC_NAME, "Boot logs sent OK\r\n" );
                iStatus = OK;
            }
            else
            {
                PLL_ERR( AMC_NAME, "ERROR sending boot logs\r\n" );
            }

            break;
        }

        default:
            iStatus = OK;
            break;
        }
    }

    return iStatus;
}

/**
 * @brief   BMC Proxy Driver EVL callback
 */
static int iBmcCallback( EVL_SIGNAL *pxSignal )
{
    int iStatus = ERROR;

    if( ( NULL != pxSignal ) && ( AMC_CFG_UNIQUE_ID_BMC == pxSignal->ucModule ) )
    {
        switch( pxSignal->ucEventType )
        {
            default:
                break;
        }
    }

    return iStatus;
}

/**
 * @brief   Get project info
 */
static void vGetProjectInfo( void )
{
    char    pcOsName[ OSAL_OS_NAME_LEN ] = "unknown";
    uint8_t ucVerMaj                     = 0, ucVerMin = 0, ucVerBld = 0;

    iOSAL_GetOsVersion( pcOsName, &ucVerMaj, &ucVerMin, &ucVerBld );

    /* Sleep so we don't interfere with any other prints. */
    iOSAL_Task_SleepMs( AMC_GET_PROJECT_INFO_SLEEP_MS );

    vPLL_Printf( "\r\n" );
    vPLL_Printf( "###############################################################\r\n" );
    vPLL_Printf( "#                                                             #\r\n" );
    vPLL_Printf( "#                             AMC                             #\r\n" );
    vPLL_Printf( "#                                                             #\r\n" );
    vPLL_Printf( "# Copyright (c) 2023 - 2025 Advanced Micro Devices, Inc.      #\r\n" );
    vPLL_Printf( "# All rights reserved.                                        #\r\n" );
    vPLL_Printf( "#                                                             #\r\n" );
    vPLL_Printf( "# SPDX-License-Identifier: MIT                                #\r\n" );
    vPLL_Printf( "#                                                             #\r\n" );
    vPLL_Printf( "###############################################################\r\n" );
    PLL_LOG( AMC_NAME,
             "AMC: %d.%d.%d-%d.%.*s.%.*s%c\r\n",
             GIT_TAG_VER_MAJOR,
             GIT_TAG_VER_MINOR,
             GIT_TAG_VER_PATCH,
             GIT_TAG_VER_DEV_COMMITS,
             AMC_HASH_LEN,
             GIT_HASH,
             AMC_DATE_LEN,
             GIT_DATE,
             ( GIT_STATUS )?( '*' ):( ' ' ) );
    PLL_LOG( AMC_NAME,
             "OS:  %s v%u.%u.%u\r\n",
             pcOsName,
             ucVerMaj,
             ucVerMin,
             ucVerBld );
    vPLL_Printf( "\r\n\r\n" );
}

/**
 * @brief   Initialise core libraries
 */
static int iInitCoreLibs( void )
{
    int iStatus = ERROR;

    if( OK == iPLL_Initialise( AMC_OUTPUT_LEVEL, AMC_LOGGING_LEVEL ) )
    {
        PLL_INF( AMC_NAME, "PLL initialised OK\r\n" );
        iStatus           = OK;
        ullAmcInitStatus |= AMC_CFG_PLL_INITIALISED;
    }
    else
    {
        PLL_ERR( AMC_NAME, "PLL initialisation ERROR\r\n" );
    }

    if( OK == iEVL_Initialise() )
    {
        PLL_INF( AMC_NAME, "EVL initialised OK\r\n" );
        iStatus           = OK;
        ullAmcInitStatus |= AMC_CFG_EVL_INITIALISED;
    }
    else
    {
        PLL_ERR( AMC_NAME, "EVL initialisation ERROR\r\n" );
    }

    return iStatus;
}

/**
 * @brief   Initialise device drivers
 */
static int iInitDeviceDrivers( void )
{
    int iStatus = OK;

    if( OK == iI2C_Init( xI2cCfg, I2C_DEFAULT_BUS_IDLE_WAIT_MS ) )
    {
        PLL_INF( AMC_NAME, "I2C driver Initialised OK\r\n" );
        ullAmcInitStatus |= AMC_CFG_I2C_INITIALISED;
    }
    else
    {
        PLL_ERR( AMC_NAME, "I2C driver Initialisation ERROR\r\n" );
        iStatus = ERROR;
    }

    if( AMC_CFG_I2C_INITIALISED == ( ullAmcInitStatus & AMC_CFG_I2C_INITIALISED ) )
    {
        if( OK == iEEPROM_Initialise( HAL_EEPROM_VERSION, &xEepromCfg ) )
        {
            PLL_INF( AMC_NAME, "iEEPROM_Initialised OK\r\n" );
            ullAmcInitStatus |= AMC_CFG_EEPROM_INITIALISED;

            if( ERROR == iEEPROM_DisplayEepromValues( ) )
            {
                PLL_ERR( AMC_NAME, "iEEPROM_DisplayEepromValues FAILED\r\n" );
            }
        }
        else
        {
            PLL_ERR( AMC_NAME, "iEEPROM_Initialised FAILED\r\n" );
        }
    }

    if( OK == iSYS_MON_Initialise() )
    {
        PLL_INF( AMC_NAME, "SysMon Driver Initialised OK\r\n" );
        ullAmcInitStatus |= AMC_CFG_SYSMON_INITIALISED;
    }
    else
    {
        PLL_ERR( AMC_NAME, "SysMon Driver Initialisation ERROR\r\n" );
        iStatus = ERROR;
    }

    return iStatus;
}

/**
 * @brief   Initialise Proxy Driver layer
 */
static int iInitProxies( void )
{
    int iStatus = OK;

    if( AMC_CFG_APC_PREREQUISITES == ( ullAmcInitStatus & AMC_CFG_APC_PREREQUISITES ) )
    {
        if( OK == iAPC_Initialise( AMC_CFG_UNIQUE_ID_APC,
                                   pxOspiIf,
                                   pxEmmcIf,
                                   AMC_TASK_PRIO_DEFAULT,
                                   AMC_TASK_DEFAULT_STACK ) )
        {
            if( OK == iAPC_BindCallback( &iApcCallback ) )
            {
                PLL_INF( AMC_NAME, "APC Proxy Driver initialised and bound\r\n" );
            }
            else
            {
                PLL_ERR( AMC_NAME, "Error binding to APC Proxy Driver\r\n" );
            }
            ullAmcInitStatus |= AMC_CFG_APC_INITIALISED;
        }
        else
        {
            PLL_ERR( AMC_NAME, "Error initialising APC Proxy Driver\r\n" );
            iStatus = ERROR;
        }
    }

    if( 0 != MAX_NUM_EXTERNAL_DEVICES_AVAILABLE )
    {
        if( AMC_CFG_AXC_PREREQUISITES == ( ullAmcInitStatus & AMC_CFG_AXC_PREREQUISITES ) )
        {
            if( OK == iAXC_Initialise( AMC_CFG_UNIQUE_ID_AXC, AMC_TASK_PRIO_DEFAULT, AMC_TASK_DEFAULT_STACK ) )
            {
                if( OK == iAXC_BindCallback( &iAxcCallback ) )
                {
                    if( ( OK == iAXC_AddExternalDevice( &xQsfpDevice1 ) ) &&
                        ( OK == iAXC_AddExternalDevice( &xQsfpDevice2 ) ) &&
                        ( OK == iAXC_AddExternalDevice( &xQsfpDevice3 ) ) &&
                        ( OK == iAXC_AddExternalDevice( &xQsfpDevice4 ) ) &&
                        ( OK == iAXC_AddExternalDevice( &xDimmDevice ) ) )
                    {
                        PLL_INF( AMC_NAME, "AXC Proxy Driver initialised and bound\r\n" );
                        ullAmcInitStatus |= AMC_CFG_AXC_INITIALISED;
                    }
                    else
                    {
                        PLL_ERR( AMC_NAME, "Error adding External Device to AXC Proxy Driver\r\n" );
                    }
                }
                else
                {
                    PLL_ERR( AMC_NAME, "Error binding to AXC Proxy Driver\r\n" );
                    iStatus = ERROR;
                }
            }
            else
            {
                PLL_ERR( AMC_NAME, "Error initialising AXC Proxy Driver\r\n" );
                iStatus = ERROR;
            }
        }
    }
    else
    {
        PLL_INF( AMC_NAME, "No external devices available - skipping AXC initialisation\r\n" );
        ullAmcInitStatus |= AMC_CFG_AXC_INITIALISED;
    }

    if( AMC_CFG_ASC_PREREQUISITES == ( ullAmcInitStatus & AMC_CFG_ASC_PREREQUISITES ) )
    {
        if( OK == iASC_Initialise( AMC_CFG_UNIQUE_ID_ASC,
                                   AMC_TASK_PRIO_DEFAULT,
                                   AMC_TASK_DEFAULT_STACK,
                                   PROFILE_SENSORS_SENSOR_DATA,
                                   PROFILE_SENSORS_NUM_SENSORS ) )
        {
            PLL_INF( AMC_NAME, "ASC Proxy Driver initialised\r\n" );
            ullAmcInitStatus |= AMC_CFG_ASC_INITIALISED;
        }
        else
        {
            PLL_ERR( AMC_NAME, "Error initialising ASC Proxy Driver\r\n" );
            iStatus = ERROR;
        }
    }

    if( AMC_CFG_AMI_PREREQUISITES == ( ullAmcInitStatus & AMC_CFG_AMI_PREREQUISITES ) )
    {
        if( OK == iAMI_Initialise( AMC_CFG_UNIQUE_ID_AMI,
                                   &xGcqIf,
                                   0,
                                   AMC_TASK_PRIO_DEFAULT,
                                   AMC_TASK_DEFAULT_STACK ) )
        {
            if( OK == iAMI_BindCallback( &iAmiCallback ) )
            {
                PLL_INF( AMC_NAME, "AMI Proxy Driver initialised and bound\r\n" );
                ullAmcInitStatus |= AMC_CFG_AMI_INITIALISED;
            }
            else
            {
                PLL_ERR( AMC_NAME, "Error binding to AMI Proxy Driver\r\n" );
            }
        }
        else
        {
            PLL_ERR( AMC_NAME, "Error initialising AMI Proxy Driver\r\n" );
            iStatus = ERROR;
        }
    }

    if( NULL != pxSMBusIf )
    {
        /* Get the UUID */
        uint8_t ucUuidSize               = 0;
        uint8_t pucUuid[ HAL_UUID_SIZE ] =
        {
            0
        };

        if( AMC_CFG_I2C_INITIALISED == ( ullAmcInitStatus & AMC_CFG_I2C_INITIALISED ) )
        {
            if( AMC_CFG_EEPROM_INITIALISED == ( ullAmcInitStatus & AMC_CFG_EEPROM_INITIALISED ) )
            {
                iStatus = iEEPROM_GetUuid( pucUuid, &ucUuidSize );
                if( OK == iStatus )
                {
                    if( HAL_UUID_SIZE != ucUuidSize )
                    {
                        PLL_ERR( AMC_NAME, "UUID Size incorrect\r\n" );
                        iStatus = ERROR;
                    }
                }
                else
                {
                    PLL_ERR( AMC_NAME, "Unable to read UUID\r\n" );
                }
            }
            else
            {
                /* Use the default (all 0s) UUID */
            }

            if( AMC_CFG_BMC_PREREQUISITES == ( ullAmcInitStatus & AMC_CFG_BMC_PREREQUISITES ) )
            {
                if( OK == iBMC_Initialise( AMC_CFG_UNIQUE_ID_BMC,
                                           pxSMBusIf,
                                           0,
                                           AMC_TASK_PRIO_DEFAULT,
                                           AMC_TASK_DEFAULT_STACK,
                                           pxPdrTemperatureSensors,
                                           TOTAL_PDR_TEMPERATURE,
                                           pxPdrVoltageSensors,
                                           TOTAL_PDR_VOLTAGE,
                                           pxPdrCurrentSensors,
                                           TOTAL_PDR_CURRENT,
                                           pxPdrPowerSensors,
                                           TOTAL_PDR_POWER,
                                           pxPdrSensorNames,
                                           TOTAL_PDR_NUMERIC_ASCI_SENSORS,
                                           pucUuid ) )
                {
                    if( OK == iBMC_BindCallback( &iBmcCallback ) )
                    {
                        PLL_INF( AMC_NAME, "BMC Proxy Driver initialised and bound\r\n" );
                        ullAmcInitStatus |= AMC_CFG_BMC_INITIALISED;
                    }
                    else
                    {
                        PLL_ERR( AMC_NAME, "Error binding to BMC Proxy Driver\r\n" );
                    }
                }
                else
                {
                    PLL_ERR( AMC_NAME, "Error initialising BMC Proxy Driver\r\n" );
                    iStatus = ERROR;
                }
            }
        }
    }
    return iStatus;
}

/**
 * @brief   Initialise App layer
 */
static int iInitApp( void )
{
    int iStatus = OK;

    if( AMC_CFG_ASDM_PREREQUISITES == ( ullAmcInitStatus & AMC_CFG_ASDM_PREREQUISITES ) )
    {
        if( OK != iASDM_Initialise( PROFILE_SENSORS_NUM_SENSORS ) )
        {
            PLL_ERR( AMC_NAME, "ASDM Initialisation ERROR\r\n" );
            iStatus = ERROR;
        }
        else
        {
            ullAmcInitStatus |= AMC_CFG_ASDM_INITIALISED;
        }
    }

    if( AMC_CFG_IN_BAND_PREREQUISITES == ( ullAmcInitStatus & AMC_CFG_IN_BAND_PREREQUISITES ) )
    {
        if( OK != iIN_BAND_TELEMETRY_Initialise( HAL_RPU_SHARED_MEMORY_BASE_ADDR ) )
        {
            PLL_ERR( AMC_NAME, "In Band Telemetry Initialisation ERROR\r\n" );
            iStatus = ERROR;
        }
        else
        {
            ullAmcInitStatus |= AMC_CFG_IN_BAND_INITIALISED;
            PLL_INF( AMC_NAME, "In-band service: ready\r\n" );
        }
    }

    if( AMC_CFG_OUT_OF_BAND_PREREQUISITES == ( ullAmcInitStatus & AMC_CFG_OUT_OF_BAND_PREREQUISITES ) )
    {
        if( OK != iOUT_OF_BAND_TELEMETRY_Initialise() )
        {
            PLL_ERR( AMC_NAME, "Out of Band Telemetry Initialisation ERROR\r\n" );
            iStatus = ERROR;
        }
        else
        {
            ullAmcInitStatus |= AMC_CFG_OUT_OF_BAND_INITIALISED;
            PLL_INF( AMC_NAME, "Out-of-band service: ready\r\n" );
        }
    }

    if( OK != iBIM_Initialise( PROFILE_BIM_MODULE_DATA ) )
    {
        PLL_ERR( AMC_NAME, "Built in Monitoring Initialisation ERROR\r\n" );
        iStatus = ERROR;
    }
    else
    {
        PLL_LOG( AMC_NAME, "Built in Monitoring (BIM) application started\r\n" );
    }

    return iStatus;
}

/**
 * @brief   Initialise Debug monitoring
 */
static int iInitDebug( void )
{
    int iStatus = OK;

#ifdef DEBUG_BUILD
    if( OK != iDAL_Initialise( "AMC_Debug", AMC_TASK_PRIO_DEFAULT, AMC_TASK_DEFAULT_STACK, &vGetProjectInfo ) )
    {
        PLL_ERR( AMC_NAME, "Unable to initialise debug menu\r\n" );
        iStatus = ERROR;
    }
    else
    {
        vDebugMenu_Initialise();
        PLL_INF( AMC_NAME, "Debug initialised\r\n" );
    }
#endif

    return iStatus;
}

/**
 * @brief   Configure the partition table stored at the start of
 *          shared memory and used by the AMI to determine the AMC state
 */
static void vConfigurePartitionTable( void )
{
    HAL_PARTITION_TABLE xPartTable =
    {
        0
    };
    uint8_t *pucDestAdd = NULL;

    xPartTable.ulMagicNum                  = HAL_PARTITION_TABLE_MAGIC_NO;
    xPartTable.xRingBuffer.ulRingBufferOff = HAL_PARTITION_TABLE_SIZE;
    xPartTable.xRingBuffer.ulRingBufferLen = HAL_RPU_RING_BUFFER_LEN;
    xPartTable.xStatus.ulStatusOff         = HAL_PARTITION_TABLE_SIZE + HAL_RPU_RING_BUFFER_LEN;
    xPartTable.xStatus.ulStatusLen         = sizeof( uint32_t );
    xPartTable.xLogMsg.ulLogMsgIndex       = 0;
    xPartTable.xLogMsg.ulLogMsgBufferOff   = xPartTable.xStatus.ulStatusOff + xPartTable.xStatus.ulStatusLen;
    xPartTable.xLogMsg.ulLogMsgBufferLen   = PLL_LOG_BUF_LEN;
    xPartTable.xData.ulDataStart           = xPartTable.xLogMsg.ulLogMsgBufferOff +
                                             xPartTable.xLogMsg.ulLogMsgBufferLen;
    xPartTable.xData.ulDataEnd = HAL_RPU_SHARED_MEMORY_SIZE;

    /* Copy the populated table into the start of shared memory */
    pucDestAdd = ( uint8_t* )( HAL_RPU_SHARED_MEMORY_BASE_ADDR );
    pvOSAL_MemCpy( pucDestAdd, ( uint8_t* )&xPartTable, sizeof( xPartTable ) );
    HAL_FLUSH_CACHE_DATA( HAL_RPU_SHARED_MEMORY_BASE_ADDR, sizeof( xPartTable ) );

    /* Flush stale logs */
    if( PLL_LOG_BUF_LEN >= xPartTable.xLogMsg.ulLogMsgBufferLen )
    {
        pvOSAL_MemSet( ( uint8_t* )( HAL_RPU_SHARED_MEMORY_BASE_ADDR + xPartTable.xLogMsg.ulLogMsgBufferOff ),
                       0,
                       xPartTable.xLogMsg.ulLogMsgBufferLen );
        HAL_FLUSH_CACHE_DATA( HAL_RPU_SHARED_MEMORY_BASE_ADDR + xPartTable.xLogMsg.ulLogMsgBufferOff,
                              xPartTable.xLogMsg.ulLogMsgBufferLen );
    }

    /*
     * AMI is waiting for the status to be set to a value of 0x1, currently we have no
     * concept of stopping/starting the AMC so once initialised this will always be valid
     */
    pucDestAdd = ( uint8_t* )( HAL_RPU_SHARED_MEMORY_BASE_ADDR + xPartTable.xStatus.ulStatusOff );
    pvOSAL_MemSet( pucDestAdd, HAL_ENABLE_AMI_COMMS, xPartTable.xStatus.ulStatusLen );
    HAL_FLUSH_CACHE_DATA( ( HAL_RPU_SHARED_MEMORY_BASE_ADDR + xPartTable.xStatus.ulStatusOff ),
                          xPartTable.xStatus.ulStatusLen );
}

