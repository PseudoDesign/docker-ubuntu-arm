# This library provides borg helper functions
# that are designed to be used by the Vagrantfile or rakefile
#
# Author::  Adam Schafer (mailto:aschafer@syncroness.com)
# License:: GPLv2

class BorgLib

  def self.create_block_devices(filename)
    `sudo kpartx -asv #{filename}`
    begin
      yield
    ensure
      sleep(0.5)
      `
      sync
      sudo kpartx -d #{filename}
      sync
      `
    end
  end

  def self.mount_partitions(filename, partitions)
    BorgLib.create_block_devices(filename) do
      partitions.each_with_index { |part, i|
        `
        sudo mkdir -p /var/.tmpmnt/#{part[:partition_name]}
        sudo mount -o loop /dev/mapper/loop0p#{i+1} /var/.tmpmnt/#{part[:partition_name]}
        `
      }
      begin
        yield
      ensure
        partitions.each { |part|
          `
          sync
          sudo umount /var/.tmpmnt/#{part[:partition_name]}
          `
        }
      end
    end
  end

  # Create a .img file with 'file_name' and 'partitions' in the form of:
  # [{partition_name: 'str', partition_start: int, partition_length: int}
  def self.create_image(file_name, partitions)
    file_length = 0
    block_size = 512
    partitions.each { |part|
      e = (part[:partition_start_sector] + part[:partition_length_sectors]) * block_size
      file_length = e if e > file_length
    }
    block_count = file_length / block_size + 1
    # Create a blank file for our system image
    `
    dd if=/dev/zero of=#{file_name} bs=#{block_size} count=#{block_count}
    `
    # Create the partition table
    partitions.each_with_index { |part, i|
      ` (
          echo n
          echo p
          echo #{i+1}
          echo #{part[:partition_start_sector]}
          echo +#{part[:partition_length_sectors]}
          echo w
        ) | fdisk #{file_name}
        sync
      `

        if part.key?(:fdisk_type)
          if i == 0
            ` (
                echo t
                echo #{part[:fdisk_type]}
                echo w
              ) | fdisk #{file_name}
              sync
            `
          else
            ` (
                echo t
                echo #{i+1}
                echo #{part[:fdisk_type]}
                echo w
              ) | fdisk #{file_name}
              sync
            `
          end
        end
    }
    `sync`
    partitions.each_with_index { |part, i|
      if part.key?(:mkfs_command)
        BorgLib.create_block_devices(file_name) do
          puts "sudo #{part[:mkfs_command]} /dev/mapper/loop0p#{i+1}"
          `
          sudo #{part[:mkfs_command]} /dev/mapper/loop0p#{i+1}
          sync
          `
        end
      end
    }
  end
end
