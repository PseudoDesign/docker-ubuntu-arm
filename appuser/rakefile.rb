require "/home/appuser/borglib.rb"
require "/share/settings.rb"

# Variables that are defined locally
UBOOT_DIR = "/home/appuser/uboot"
LINUX_DIR = "/home/appuser/linux"
ROOTFS_DIR = "/home/appuser/ubuntu"
PARTITIONS_DIR = "/home/appuser/partitions"
BOOT_PARITION_DIR = PARTITIONS_DIR + "/boot"
ROOTFS_PARITION_DIR = PARTITIONS_DIR + "/rootfs"

KERNEL_CONFIGS_DIR = LINUX_DIR + "/arch/arm/configs"

SOURCES_LOG_FILE = "/home/appuser/log.txt"
HOST_PACKAGES_LOG_FILE = "/home/appuser/host_package_log.txt"

TARGET_PACKAGES_LOG_FILENAME = "target_package_log.txt"

UBUNTU_VERSION = "xenial"

TEMP_SD_FILENAME = "/home/appuser/.build.img"

RELEASE_DIRECTORY = "/share/release_#{Time.now.strftime('%Y-%m-%d_%H-%M-%S')}"

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
  sh "apt list --installed > #{HOST_PACKAGES_LOG_FILE}"
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
  if defined? ENABLE_ROOT_ACCOUNT and ENABLE_ROOT_ACCOUNT
    bootstrap_script += "
    (echo '#{ROOT_PASSWORD}'; echo '#{ROOT_PASSWORD}') | passwd root
    "
  end
  bootstrap_script += "
  apt list --installed > /#{TARGET_PACKAGES_LOG_FILENAME}
  "
  File.write(".bootstrap.sh", bootstrap_script)
   `
    sudo chown root:root .bootstrap.sh
    sudo chmod +x .bootstrap.sh
    sudo mv .bootstrap.sh #{ROOTFS_DIR}
    sudo chroot #{ROOTFS_DIR} ./.bootstrap.sh
   `
  # Run the bootstrap extras
  if defined? BOOTSTRAP_EXTRA_SCRIPT and BOOTSTRAP_EXTRA_SCRIPT
    `
     sudo cp /share/#{BOOTSTRAP_EXTRA_SCRIPT} #{ROOTFS_DIR}/.extra.sh
     sudo chown root:root #{ROOTFS_DIR}/.extra.sh
     sudo chmod +x #{ROOTFS_DIR}/.extra.sh
     sudo chroot #{ROOTFS_DIR} ./.extra.sh
    `
  end
   # Copy the packages log file
   `sudo cp #{ROOTFS_DIR}/#{TARGET_PACKAGES_LOG_FILENAME} /home/appuser`
end

# Tasks related to building the Linux kernel

task :clean_linux do
  sh "rm -rf #{LINUX_DIR}"
end

task :get_linux do
  add_to_version_log("Linux Repo", LINUX_REPO)
  add_to_version_log("Linux Branch", LINUX_BRANCH)
  sh "git clone --single-branch -b #{LINUX_BRANCH} #{LINUX_REPO} #{LINUX_DIR}"
  if defined? IMPORT_KERNEL_DEFCONFIG and IMPORT_KERNEL_DEFCONFIG
    sh "cp #{IMPORT_KERNEL_DEFCONFIG} #{KERNEL_CONFIGS_DIR}"
  end
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
  sh "git clone --single-branch -b #{UBOOT_BRANCH} #{UBOOT_REPO} #{UBOOT_DIR}"
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

task :sd_card => [:release, :boot_partition, :rootfs_partition] do
  sh "rm -f #{TEMP_SD_FILENAME}"
  BorgLib.create_image(TEMP_SD_FILENAME, PARTITION_INFO)
  BorgLib.mount_partitions(TEMP_SD_FILENAME, PARTITION_INFO) do
    `
      sudo cp -r #{BOOT_PARITION_DIR}/* /var/.tmpmnt/boot
      sudo cp -r #{ROOTFS_PARITION_DIR}/* /var/.tmpmnt/rootfs1
    `
  end
  # Write uboot
  `
  dd conv=notrunc if=#{UBOOT_DIR}/#{UBOOT_BINARY_NAME} of=#{TEMP_SD_FILENAME} bs=512 seek=2
  `
  # Copy file to /share
  `
  sudo cp #{TEMP_SD_FILENAME} #{RELEASE_DIRECTORY}/output.img
  `
end

task :release => [:packages_log, :clean_version_log, :linux, :uboot, :rootfs] do
  add_to_version_log("Timestamp", `date`)
  add_to_version_log("Root Password", ROOT_PASSWORD)
  # Copy log files to share
  sh "sudo mkdir -p #{RELEASE_DIRECTORY}"
  sh "sudo cp /home/appuser/*.txt #{RELEASE_DIRECTORY}"
end
