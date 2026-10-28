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

#include "zynq_plat.h"

static uint32_t current_device = 0;

void assign_device_id(struct bus_driver_data *bd_data) {
    bd_data->dev_id = current_device++;
    dbg_info("fpga device id %d, platform device %s\n", bd_data->dev_id, dev_name(bd_data->dev));
    sprintf(bd_data->vfpga_dev_name, "%s_%d", DEV_FPGA_NAME, bd_data->dev_id);
    sprintf(bd_data->reconfig_dev_name, "%s_reconfig", bd_data->vfpga_dev_name);
}

int irq_setup(struct bus_driver_data *bd_data, struct platform_device *pdev, bool enable_reconfig_irq) {
    BUG_ON(!bd_data);
    BUG_ON(!pdev);

    // vFPGA IRQ
    int i, ret_val = 0;
    for (i = 0; i < bd_data->n_fpga_reg; i++) {
        // The i-th interrupt in the device tree is wired to the i-th user interrupt of the static layer
        int vector = platform_get_irq(pdev, i);
        if (vector < 0) {
            ret_val = vector;
            pr_err("couldn't obtain IRQ %d from the device tree, ret=%d\n", i, ret_val);
            goto err_user;
        }

        bd_data->irq_entry[i].vector = vector;
        ret_val = request_irq(vector, vfpga_isr, 0, COYOTE_DRIVER_NAME, &bd_data->vfpga_dev[i]);

        if (ret_val) {
            pr_err("couldn't use IRQ#%d, ret=%d\n", vector, ret_val);
            goto err_user;
        }

        dbg_info("using IRQ#%d with vFPGA %d\n", vector, bd_data->vfpga_dev[i].id);
    }

    // Reconfiguration IRQ
    if (enable_reconfig_irq) {
        int vector = platform_get_irq(pdev, FPGA_RECONFIG_IRQ_VECTOR);
        if (vector < 0) {
            ret_val = vector;
            pr_err("couldn't obtain reconfiguration IRQ from the device tree, ret=%d\n", ret_val);
            goto err_reconfig;
        }

        bd_data->irq_entry[FPGA_RECONFIG_IRQ_VECTOR].vector = vector;
        ret_val = request_irq(vector, reconfig_isr, 0, COYOTE_DRIVER_NAME, bd_data->reconfig_dev);

        if (ret_val) {
            pr_err("couldn't use reconfiguration IRQ#%d, ret=%d\n", vector, ret_val);
            goto err_reconfig;
        }

        dbg_info("using IRQ#%d with reconfiguration device\n", vector);
    }

    return ret_val;

err_reconfig:
    for (i = 0; i < bd_data->n_fpga_reg; i++) { free_irq(bd_data->irq_entry[i].vector, &bd_data->vfpga_dev[i]); }
    return ret_val;

err_user:
    while (--i >= 0) { free_irq(bd_data->irq_entry[i].vector, &bd_data->vfpga_dev[i]); }
    return ret_val;
}

void irq_teardown(struct bus_driver_data *bd_data, bool enable_reconfig_irq) {
    BUG_ON(!bd_data);

    for (int i = 0; i < bd_data->n_fpga_reg; i++) {
        dbg_info("releasing user IRQ%d\n", bd_data->irq_entry[i].vector);
        free_irq(bd_data->irq_entry[i].vector, &bd_data->vfpga_dev[i]);
    }

    if (enable_reconfig_irq) {
        dbg_info("releasing reconfiguration IRQ%d\n", bd_data->irq_entry[FPGA_RECONFIG_IRQ_VECTOR].vector);
        free_irq(bd_data->irq_entry[FPGA_RECONFIG_IRQ_VECTOR].vector, bd_data->reconfig_dev);
    }
}

int map_regions(struct bus_driver_data *bd_data, struct platform_device *pdev) {
    // Static (axi_cnfg) and shell (axi_main) configuration windows, see hw/bd/zynq_us_plus/cr_ps.tcl
    const char *names[] = {"stat", "shell"};
    const int idx[] = {BAR_STAT_CONFIG, BAR_SHELL_CONFIG};

    for (int i = 0; i < 2; i++) {
        struct resource *res = platform_get_resource_byname(pdev, IORESOURCE_MEM, names[i]);
        if (!res) {
            dev_err(&pdev->dev, "missing '%s' region in the device tree\n", names[i]);
            return -ENODEV;
        }

        if (!devm_request_mem_region(&pdev->dev, res->start, resource_size(res), COYOTE_DRIVER_NAME)) {
            dev_err(&pdev->dev, "'%s' region in use\n", names[i]);
            bd_data->regions_in_use = 1;
            return -EBUSY;
        }

        // Only the physical addresses are needed; the regions are mapped (to kernel- and user-space) where used
        bd_data->bar[idx[i]] = NULL;
        bd_data->bar_phys_addr[idx[i]] = res->start;
        bd_data->bar_len[idx[i]] = resource_size(res);
        dbg_info("region %s at 0x%llx, length=%llu\n", names[i], (u64) res->start, (u64) resource_size(res));
    }

    bd_data->got_regions = 1;
    return 0;
}

int shell_pci_init(struct bus_driver_data *bd_data) {
    int ret_val = 0;
    dbg_info("initializing shell ...\n");

    // Obtain dynamic major and minor numbers for the FPGA device
    dev_t dev_vfpga = MKDEV(bd_data->vfpga_major, 0);

    // Read shell config
    ret_val = read_shell_config(bd_data);
    if (ret_val) {
        pr_err("cannot read static config\n");
        goto err_read_shell_cnfg;
    }

    // Create sysfs entry
    ret_val = create_sysfs_entry(bd_data);
    if (ret_val) {
        pr_err("cannot create a sysfs entry\n");
        goto err_sysfs;
    }

    // Allocate card memory resources
    ret_val = allocate_card_resources(bd_data);
    if (ret_val) {
        pr_err("card resources could not be allocated\n");
        goto err_card_alloc;
    }

    // Create vFPGA devices and register major number
    ret_val = alloc_vfpga_devices(bd_data, dev_vfpga);
    if (ret_val) {
        goto err_create_fpga_dev;
    }

    // Set-up the above-created vFPGAs
    ret_val = setup_vfpga_devices(bd_data);
    if (ret_val) {
        goto err_init_fpga_dev;
    }

    // Set-up vFPGAs IRQs
    ret_val = irq_setup(bd_data, to_platform_device(bd_data->dev), false);
    if (ret_val) {
        pr_err("IRQ setup error\n");
        goto err_irq;
    }

    if (ret_val == 0) { goto end; }

err_irq:
    teardown_vfpga_devices(bd_data);
err_init_fpga_dev:
    free_vfpga_devices(bd_data);
err_create_fpga_dev:
    free_card_resources(bd_data);
err_card_alloc:
    remove_sysfs_entry(bd_data);
err_sysfs:
err_read_shell_cnfg:
end:
    dbg_info("shell load returning %d\n", ret_val);
    return ret_val;
}

void shell_pci_remove(struct bus_driver_data *bd_data) {
    dbg_info("removing shell...\n");

    // Free HMM chunks
    #ifdef HMM_KERNEL
        free_mem_regions(bd_data);
        dbg_info("freed svm private pages");
    #endif

    // Remove vFPGA interrupts
    irq_teardown(bd_data, false);
    dbg_info("vfpga interrupts disabled\n");

    // Clear and release vFPGAs devices
    teardown_vfpga_devices(bd_data);
    free_vfpga_devices(bd_data);
    dbg_info("vfpga devices released\n");

    // Deallocate card memory resources
    free_card_resources(bd_data);
    dbg_info("card memory resources released\n");

    // Remove sysfs entry
    remove_sysfs_entry(bd_data);
    dbg_info("sysfs removed\n");

    dbg_info("shell removed\n");
}

int zynq_probe(struct platform_device *pdev) {
    int ret_val = 0;
    dbg_info("probe (pdev = 0x%p)\n", pdev);

    // Allocate memory for the device instance
    struct bus_driver_data *bd_data = devm_kzalloc(&pdev->dev, sizeof(struct bus_driver_data), GFP_KERNEL);
    if (!bd_data) {
        dev_err(&pdev->dev, "device memory region not obtained\n");
        ret_val = -ENOMEM;
        goto err_alloc;
    }

    // Set device private bd_data; there is no PCI device on Zynq platforms
    bd_data->pci_dev = NULL;
    bd_data->dev = &pdev->dev;
    platform_set_drvdata(pdev, bd_data);

    // Obtain a (dynamic) major and minor number for the vFPGA device and reconfig device
    bd_data->vfpga_major = VFPGA_DEV_MAJOR;
    bd_data->reconfig_major = RECONFIG_DEV_MAJOR;
    dev_t dev_vfpga = MKDEV(bd_data->vfpga_major, 0);
    dev_t dev_reconfig = MKDEV(bd_data->reconfig_major, 0);

    // Set unique ID for this FPGA
    assign_device_id(bd_data);

    // Configuration windows
    ret_val = map_regions(bd_data, pdev);
    if (ret_val) {
        dev_err(&pdev->dev, "configuration regions could not be obtained\n");
        goto err_regions;
    }

    // DMA addressing
    ret_val = dma_set_mask_and_coherent(&pdev->dev, DMA_BIT_MASK(TLB_PADDR_RANGE)); // 44
    if (ret_val) {
        dev_err(&pdev->dev, "failed to set DMA mask\n");
        goto err_mask;
    }

    // Coyote maps user buffers once and never syncs caches explicitly (see vfpga_gup.c); without
    // coherent DMA (HPC ports + dma-coherent in the device tree), the FPGA would see stale data
    if (!of_dma_is_coherent(pdev->dev.of_node)) {
        dev_warn(&pdev->dev, "device is not marked dma-coherent; host DMA will likely return stale data\n");
    }

    // Initialize spin locks
    init_spin_locks(bd_data);

    // Memory map static and shell configuration registers into the kernel space
    bd_data->stat_cnfg = ioremap(bd_data->bar_phys_addr[BAR_STAT_CONFIG] + FPGA_STAT_CNFG_OFFS, FPGA_STAT_CNFG_SIZE);
    bd_data->shell_cnfg = ioremap(bd_data->bar_phys_addr[BAR_SHELL_CONFIG] + FPGA_SHELL_CNFG_OFFS, FPGA_SHELL_CNFG_SIZE);
    if (!bd_data->stat_cnfg || !bd_data->shell_cnfg) {
        dev_err(&pdev->dev, "configuration registers could not be mapped\n");
        ret_val = -ENOMEM;
        goto err_cnfg_map;
    }

    // Assert shell reset
    bd_data->stat_cnfg->reconfig_eost_reset = 0x0;
    wmb();
    usleep_range(DMA_MIN_SLEEP_CMD, DMA_MIN_SLEEP_CMD);

    bd_data->stat_cnfg->reconfig_eost_reset = 0x1;
    wmb();
    usleep_range(DMA_MIN_SLEEP_CMD, DMA_MIN_SLEEP_CMD);

    // Read shell config
    ret_val = read_shell_config(bd_data);
    if(ret_val) {
        dev_err(&pdev->dev, "cannot read shell config\n");
        goto err_read_shell_cnfg;
    }

    // Create sysfs entry
    ret_val = create_sysfs_entry(bd_data);
    if (ret_val) {
        dev_err(&pdev->dev, "cannot create a sysfs entry\n");
        goto err_sysfs;
    }

    // Allocate card memory resources
    ret_val = allocate_card_resources(bd_data);
    if (ret_val) {
        dev_err(&pdev->dev, "card memory resources could not be allocated\n");
        goto err_card_alloc;
    }

    // Create reconfig device and register major
    ret_val = alloc_reconfig_device(bd_data, dev_reconfig);
    if (ret_val) {
        dev_err(&pdev->dev, "could not allocate reconfig device\n");
        goto err_create_reconfig_dev;
    }

    // Set-up reconfig device
    ret_val = setup_reconfig_device(bd_data);
    if (ret_val) {
        dev_err(&pdev->dev, "could not set-up reconfig device\n");
        goto err_init_reconfig_dev;
    }

    // Create vFPGA devices and register major
    ret_val = alloc_vfpga_devices(bd_data, dev_vfpga);
    if (ret_val) {
        dev_err(&pdev->dev, "could not allocate vfpga devices\n");
        goto err_create_fpga_dev;
    }

    // Set-up vFPGA devices
    ret_val = setup_vfpga_devices(bd_data);
    if (ret_val) {
        dev_err(&pdev->dev, "could not set-up vfpga devices\n");
        goto err_init_fpga_dev;
    }

    // Set-up IRQs
    ret_val = irq_setup(bd_data, pdev, true);
    if (ret_val) {
        dev_err(&pdev->dev, "IRQ setup error\n");
        goto err_irq;
    }

    if (ret_val == 0)
        goto end;

err_irq:
    teardown_vfpga_devices(bd_data);
err_init_fpga_dev:
    free_vfpga_devices(bd_data);
err_create_fpga_dev:
    teardown_reconfig_device(bd_data);
err_init_reconfig_dev:
    free_reconfig_device(bd_data);
err_create_reconfig_dev:
    free_card_resources(bd_data);
err_card_alloc:
    remove_sysfs_entry(bd_data);
err_sysfs:
err_read_shell_cnfg:
err_cnfg_map:
    if (bd_data->stat_cnfg) { iounmap(bd_data->stat_cnfg); }
    if (bd_data->shell_cnfg) { iounmap(bd_data->shell_cnfg); }
err_mask:
err_regions:
err_alloc:
end:
    dbg_info("probe returning %d\n", ret_val);
    return ret_val;
}

#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 11, 0)
static void zynq_remove(struct platform_device *pdev) {
#else
static int zynq_remove(struct platform_device *pdev) {
#endif
    struct bus_driver_data *bd_data = (struct bus_driver_data *) platform_get_drvdata(pdev);

    // Free HMM chunks
    #ifdef HMM_KERNEL
        free_mem_regions(bd_data);
        dbg_info("freed svm private pages");
    #endif

    // Remove interrupts
    irq_teardown(bd_data, true);
    dbg_info("interrupts disabled\n");

    // Clear and release vFPGA devices
    teardown_vfpga_devices(bd_data);
    free_vfpga_devices(bd_data);
    dbg_info("vfpga devices released\n");

    // Clear and release reconfiguration device
    teardown_reconfig_device(bd_data);
    free_reconfig_device(bd_data);
    dbg_info("reconfig device released\n");

    // Deallocate card resources
    free_card_resources(bd_data);
    dbg_info("card memory resources released\n");

    // Remove sysfs entry
    remove_sysfs_entry(bd_data);
    dbg_info("sysfs remove\n");

    // Unmap configuration registers; the regions and bd_data are device-managed (devm_*) and released automatically
    iounmap(bd_data->stat_cnfg);
    iounmap(bd_data->shell_cnfg);
    dbg_info("configuration registers unmapped\n");

    dbg_info("removal completed\n");

#if LINUX_VERSION_CODE < KERNEL_VERSION(6, 11, 0)
    return 0;
#endif
}

// Device tree nodes which can be used with the Coyote driver; see driver/dts/coyote_zcu216.dtso
static const struct of_device_id zynq_of_ids[] = {
    { .compatible = "ethz,coyote-zynqmp", },
    {},
};
MODULE_DEVICE_TABLE(of, zynq_of_ids);

static struct platform_driver zynq_driver = {
    .driver = {
        .name = COYOTE_DRIVER_NAME,
        .of_match_table = zynq_of_ids,
    },
    .probe = zynq_probe,
    .remove = zynq_remove,
};

int pci_init(void) {
    int ret_val = platform_driver_register(&zynq_driver);
    if (ret_val) {
        pr_err("failed to register coyote platform driver, ret_val %d\n", ret_val);
        return ret_val;
    }

    return 0;
}

void pci_exit(void) {
    platform_driver_unregister(&zynq_driver);
}
