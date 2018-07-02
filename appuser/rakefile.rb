# Variables that need to be defined in a settings file
LINUX_BRANCH = "Ubuntu-4.4.0-128.154"
LINUX_REPO = "git://kernel.ubuntu.com/ubuntu/ubuntu-xenial.git"

UBOOT_BRANCH = "rel_imx_4.9.x_1.0.0_ga"
UBOOT_REPO = "git://git.freescale.com/imx/uboot-imx.git"

UBOOT_CONFIG = 'mx6ull_14x14_evk_defconfig'
KERNEL_CONFIG = 'imx_v6_v7_defconfig'

# Variables that are defined locally
UBOOT_DIR = "/home/appuser/uboot"
LINUX_DIR = "/home/appuser/linux"

SOURCES_LOG_FILE = "/home/appuser/log.txt"
PACKAGES_LOG_FILE = "/home/appuser/package_log.txt"

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

# Tasks releated to building a released version of the system

task :release => [:packages_log, :clean_version_log, :linux, :uboot] do
  add_to_version_log("Timestamp", `date`)
end
