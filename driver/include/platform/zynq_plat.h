/*
 * Copyright (c) 2025,  Systems Group, ETH Zurich
 * All rights reserved.
 *
 * This file is part of the Coyote device driver for Linux.
 * Coyote can be found at: https://github.com/fpgasystems/Coyote
 *
 * This source code is free software; you can redistribute it and/or modify it
 * under the terms and conditions of the GNU General Public License,
 * version 2, as published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
 * more details.
 *
 * The full GNU General Public License is included in this distribution in
 * the file called "COPYING". If not found, a copy of the GNU General Public
 * License can be found <https://www.gnu.org/licenses/>.
 */

/**
 * @file zynq_plat.h
 * @brief Contains functions for loading and setting up the Coyote driver on Zynq UltraScale+ platforms (experimental)
 *
 * On Zynq platforms, the host is the on-chip processing system (PS) and Coyote is a platform device, described
 * in the device tree (see driver/dts/coyote_zcu216.dtso), rather than a PCI device:
 *  - The static (axi_cnfg) and shell (axi_main) configuration windows are the equivalents of the
 *    BAR_STAT_CONFIG and BAR_SHELL_CONFIG BARs; there is no equivalent of BAR_DMA_CONFIG (no XDMA core)
 *  - The PL-to-PS interrupts are the equivalents of the MSI-X vectors; the i-th interrupt in the
 *    device tree corresponds to MSI-X vector i (vFPGA i, and FPGA_RECONFIG_IRQ_VECTOR for reconfiguration)
 *  - Host memory is accessed through the coherent (HPC) PS ports; since Coyote maps buffers once and never
 *    syncs caches explicitly, the device must be marked dma-coherent in the device tree
 */

#ifdef PLATFORM_ZYNQ

#ifndef _ZYNQ_PLAT_H_
#define _ZYNQ_PLAT_H_

#include <linux/platform_device.h>
#include <linux/of.h>
#include <linux/of_address.h>

#include "coyote_defs.h"
#include "coyote_setup.h"

/// Assign a unique ID to each Coyote-enabled FPGA and set the unique device name
void assign_device_id(struct bus_driver_data *data);

//////////////////////////////////////////////
//                INTERRUPTS               //
////////////////////////////////////////////

/**
 * @brief Sets up Coyote IRQs for vfpga and reconfig devices
 *
 * Same as on PCI platforms, but the IRQs are obtained from the device tree instead of MSI-X.
 * Unlike the XDMA core, the PS has no interrupt mask registers; the interrupts are enabled once requested.
 *
 * @param data Pointer to the bus driver data structure, containing Coyote device information
 * @param pdev Pointer to the platform device associated with the Coyote device
 * @param enable_reconfig_irq Boolean flag to enable reconfiguration interrupts; see irq_setup in pci_xdma.h
 * @return 0 on success, negative error code on failure
 */
int irq_setup(struct bus_driver_data *data, struct platform_device *pdev, bool enable_reconfig_irq);

/**
 * @brief Removes previously set-up IRQs (opposite of irq_setup)
 *
 * @param data Pointer to the bus driver data structure, containing Coyote device information
 * @param enable_reconfig_irq Boolean flag to disable reconfiguration interrupts; same purpose as in irq_setup
 */
void irq_teardown(struct bus_driver_data *data, bool enable_reconfig_irq);

//////////////////////////////////////////////
//                REGIONS                  //
////////////////////////////////////////////

/**
 * @brief Obtains the static and shell configuration windows from the device tree
 *
 * Fills in bar_phys_addr and bar_len for BAR_STAT_CONFIG and BAR_SHELL_CONFIG, so the rest
 * of the driver (e.g., memory-mapping the vFPGA regions to user-space) works as on PCI platforms.
 *
 * @param data Pointer to the bus driver data structure, containing Coyote device information
 * @param pdev Pointer to the platform device associated with the Coyote device
 * @return 0 on success, negative error code on failure
 */
int map_regions(struct bus_driver_data *data, struct platform_device *pdev);

//////////////////////////////////////////////
//                DRIVER                   //
////////////////////////////////////////////

/**
 * @brief (Re-)Initializes the Coyote shell; equivalent of shell_pci_init on PCI platforms
 *
 * Keeps the same name as on PCI platforms, since it is called from reconfig_ops.c
 * Note, shell reconfiguration is not supported yet on Zynq platforms (EN_SHELL_PBLOCK=0)
 *
 * @param data Pointer to the bus driver data structure, containing Coyote device information
 * @return 0 on success, negative error code on failure.
 */
int shell_pci_init(struct bus_driver_data *data);

/**
 * @brief Clears the state of the Coyote shell; equivalent of shell_pci_remove on PCI platforms
 *
 * @param data Pointer to the bus driver data structure, containing Coyote device information
 */
void shell_pci_remove(struct bus_driver_data *data);

/**
 * @brief Top-level platform device initialization function for the Coyote driver
 *
 * Called when a matching device tree node is found (e.g., when the device tree overlay is applied
 * after loading the bitstream); same steps as pci_probe, without the PCI and XDMA set-up
 */
int zynq_probe(struct platform_device *pdev);

/// Top-level entry function, called by coyote_init; keeps the same name as on PCI platforms
int pci_init(void);

/// Top-level exit function, called by coyote_exit; keeps the same name as on PCI platforms
void pci_exit(void);

#endif // _ZYNQ_PLAT_H_

#endif // PLATFORM_ZYNQ
