# Variables that need to be defined in a settings file
LINUX_BRANCH = "Ubuntu-4.4.0-128.154"
LINUX_REPO = "git://kernel.ubuntu.com/ubuntu/ubuntu-xenial.git"

UBOOT_BRANCH = "rel_imx_4.9.x_1.0.0_ga"
UBOOT_REPO = "git://git.freescale.com/imx/uboot-imx.git"

UBOOT_CONFIG = 'mx6ull_14x14_evk_defconfig'
KERNEL_CONFIG = 'imx_v6_v7_defconfig'

DTB_NAME = "imx6q-sabreauto.dtb"

ENABLE_ROOT_ACCOUNT = true
ENABLE_IMX_SERIAL_CONSOLE = true
ROOT_PASSWORD = "12345"

UBOOT_BINARY_NAME = "u-boot-dtb.imx"

PARTITION_INFO = [
  {
    partition_name: "boot",
    partition_start_sector: 2048,
    partition_length_sectors: (1024 * 1024 * 500 / 4)/512,
    fdisk_type: "6", # FAT16
    mkfs_command: "mkfs.vfat"
  },
  {
    partition_name: "rootfs1",
    partition_start_sector: 280000,
    partition_length_sectors: (1024 * 1024 * 500)/512,
    mkfs_command: "mkfs.ext3"
  }
]
