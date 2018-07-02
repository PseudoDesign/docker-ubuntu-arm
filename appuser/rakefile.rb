LINUX_BRANCH = Ubuntu-4.4.0-128.154
LINUX_REPO = git://kernel.ubuntu.com/ubuntu/ubuntu-xenial.git

task :get_linux do
  sh "git clone --depth=1 --single-branch -b #{LINUX_BRANCH} #{LINUX_REPO} /app/sources/linux"
end

task :get_uboot do
  sh "git clone --depth=1 --single-branch -b #{LINUX_BRANCH} #{LINUX_REPO} /app/sources/linux"
end
