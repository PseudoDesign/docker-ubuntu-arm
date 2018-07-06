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

# Variables that are defined locally
UBOOT_DIR = "/home/appuser/uboot"
LINUX_DIR = "/home/appuser/linux"
ROOTFS_DIR = "/home/appuser/ubuntu"
PARTITIONS_DIR = "/home/appuser/partitions"
BOOT_PARITION_DIR = PARTITIONS_DIR + "/boot"
ROOTFS_PARITION_DIR = PARTITIONS_DIR + "/rootfs"

SOURCES_LOG_FILE = "/home/appuser/log.txt"
PACKAGES_LOG_FILE = "/home/appuser/package_log.txt"

UBUNTU_VERSION = "xenial"

def crossmake(target)
  arch = "arm"
  cross_compile = "arm-linux-gnueabihf-"
  cores = "4"

  sh "make ARCH=#{arch} CROSS_COMPILE=#{cross_compile} -j#{cores} #{target}"
end

def add_to_version_log(title, version)
  sh "echo '#{title}: #{version}' >> #{SOURCES_LOG_FILE}"
end

task :clean_version_log do
  sh "rm -f #{SOURCES_LOG_FILE}"
end

task :packages_log do
  sh "apt list --installed > #{PACKAGES_LOG_FILE}"
end

# Tasks related to building the Ubuntu rootfs

task :clean_rootfs do
  sh "rm -rf #{ROOTFS_DIR}"
end

task :rootfs do
  # Install stage one of our rootfs
  `
  mkdir -p #{ROOTFS_DIR}
  sudo debootstrap --arch=armhf --foreign --include=ubuntu-keyring,apt-transport-https,ca-certificates,openssl #{UBUNTU_VERSION} "#{ROOTFS_DIR}" http://ports.ubuntu.com
  sudo cp /usr/bin/qemu-arm-static #{ROOTFS_DIR}/usr/bin
  sudo cp /etc/resolv.conf #{ROOTFS_DIR}/etc
  `
  # chroot into the rootfs dir, then run second stage
  bootstrap_script =
  "
   set -v
   export LC_ALL=C LANGUAGE=C LANG=C
   /debootstrap/debootstrap --second-stage
   echo \"deb http://ports.ubuntu.com/ubuntu-ports/ #{UBUNTU_VERSION} main restricted universe multiverse\" > /etc/apt/sources.list
   echo \"deb http://ports.ubuntu.com/ubuntu-ports/ #{UBUNTU_VERSION}-updates main restricted universe multiverse\" >> /etc/apt/sources.list
   echo \"deb http://ports.ubuntu.com/ubuntu-ports/ #{UBUNTU_VERSION}-security main restricted universe multiverse\" >> /etc/apt/sources.list
   apt-key add --recv-keys --keyserver keyserver.ubuntu.com 40976EAF437D05B5
   apt-key add --recv-keys --keyserver keyserver.ubuntu.com 3B4FE6ACC0B21F32
   apt-get update
   apt-get upgrade -y
   apt-get install -y vim
  "
  bootstrap_script += "echo '#{ROOT_PASSWORD}' passwd root --stdin\n" if defined? ENABLE_ROOT_ACCOUNT and ENABLE_ROOT_ACCOUNT
  if defined? ENABLE_IMX_SERIAL_CONSOLE and ENABLE_IMX_SERIAL_CONSOLE
    bootstrap_script = "
     ln -s /lib/systemd/system/getty@.service getty@ttymxc0.service
     systemctl enable getty@ttymxc0.service
    "
  end
  File.write(".bootstrap.sh", bootstrap_script)
   `
    sudo chown root:root .bootstrap.sh
    sudo chmod +x .bootstrap.sh
    sudo mv .bootstrap.sh #{ROOTFS_DIR}
    sudo chroot #{ROOTFS_DIR} ./.bootstrap.sh
   `
   # Clean up qemu and resolv.conf
   `
    sudo rm #{ROOTFS_DIR}/etc/resolv.conf
    sudo rm #{ROOTFS_DIR}/usr/bin/qemu-arm-static
   `
end

# Tasks related to building the Linux kernel

task :clean_linux do
  sh "rm -rf #{LINUX_DIR}"
end

task :get_linux do
  add_to_version_log("Linux Repo", LINUX_REPO)
  add_to_version_log("Linux Branch", LINUX_BRANCH)
  sh "git clone --depth=1 --single-branch -b #{LINUX_BRANCH} #{LINUX_REPO} #{LINUX_DIR}"
end

task :linux => [:get_linux] do
  add_to_version_log("KERNEL_CONFIG", KERNEL_CONFIG)
  Dir.chdir(LINUX_DIR) do
    crossmake(KERNEL_CONFIG)
    crossmake("zImage modules dtbs")
    add_to_version_log("Linux Commit Hash", `git rev-parse HEAD`)
  end
end

# Tasks related to building uboot

task :clean_uboot do
  sh "rm -rf #{UBOOT_DIR}"
end

task :get_uboot do
  add_to_version_log("Uboot Repo", UBOOT_REPO)
  add_to_version_log("Uboot Branch", UBOOT_BRANCH)
  sh "git clone --depth=1 --single-branch -b #{UBOOT_BRANCH} #{UBOOT_REPO} #{UBOOT_DIR}"
end

task :uboot => [:get_uboot] do
  add_to_version_log("UBOOT_CONFIG", UBOOT_CONFIG)
  Dir.chdir(UBOOT_DIR) do
    crossmake(UBOOT_CONFIG)
    crossmake("")
    add_to_version_log("Uboot Commit Hash", `git rev-parse HEAD`)
  end
end

# Tasks related to populating the boot and rootfs partitions

task :clean_partitions do
  sh "rm -rf #{PARTITIONS_DIR}"
end

task :boot_partition do
  # Note that the build needs to be completed to do this install.
  sh "mkdir -p #{BOOT_PARITION_DIR}"
  # Install the kernel image
  sh "cp #{LINUX_DIR}/arch/arm/boot/zImage #{BOOT_PARITION_DIR}"
  # Install the dtb(s)
  sh "cp #{LINUX_DIR}/arch/arm/boot/dts/#{DTB_NAME} #{BOOT_PARITION_DIR}"
end

task :rootfs_partition do
  # Note that the build needs to be completed to do this install
  sh "mkdir -p #{ROOTFS_PARITION_DIR}"
  # Copy the rootfs
  sh "sudo cp -r #{ROOTFS_DIR}/* #{ROOTFS_PARITION_DIR}"
  # Install headers
  sh "sudo make -C #{LINUX_DIR} ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- headers_install INSTALL_HDR_PATH=#{ROOTFS_PARITION_DIR}/usr  "
  # Install firmware
  sh "sudo make -C #{LINUX_DIR} modules_install firmware_install INSTALL_MOD_PATH=#{ROOTFS_PARITION_DIR} ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- "
end

# Tasks releated to building a released version of the system

task :release => [:packages_log, :clean_version_log, :linux, :uboot] do
  add_to_version_log("Timestamp", `date`)
  add_to_version_log("Root Password", ROOT_PASSWORD)
end
