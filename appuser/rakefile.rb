# Variables that need to be defined in a settings file
LINUX_BRANCH = "Ubuntu-4.4.0-128.154"
LINUX_REPO = "git://kernel.ubuntu.com/ubuntu/ubuntu-xenial.git"

UBOOT_BRANCH = "rel_imx_4.9.x_1.0.0_ga"
UBOOT_REPO = "git://git.freescale.com/imx/uboot-imx.git"

UBOOT_CONFIG = 'mx6ull_14x14_evk_defconfig'

# Variables that are defined locally
UBOOT_DIR = "/home/appuser/uboot"
LINUX_DIR = "/home/appuser/linux"

def crossmake(target)
  arch = "arm"
  cross_compile = "arm-linux-gnueabihf-"
  cores = "4"

  sh "make ARCH=#{arch} CROSS_COMPILE=#{cross_compile} -j#{cores} #{target}"
end

task :get_linux do
  sh "git clone --depth=1 --single-branch -b #{LINUX_BRANCH} #{LINUX_REPO} #{LINUX_DIR}"
end

task :get_uboot do
  sh "git clone --depth=1 --single-branch -b #{UBOOT_BRANCH} #{UBOOT_REPO} #{UBOOT_DIR}"
end

task :uboot => [:get_uboot] do
  uboot_config = UBOOT_CONFIG
  Dir.chdir(UBOOT_DIR) do
    crossmake(uboot_config)
    crossmake("")
  end
end
