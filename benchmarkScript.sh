#!/bin/bash


### Instructions:
### This script does multiple tests on an instance (prepared for Ubuntu 16.04),
### and is run as "ubuntu" user which requires full sudo privileges.
###
### The script is run as "./script.sh argument1 argument2 argument3"
### Example: "./script.sh t2.micro 10.0.0.106 xvd"
### NOTE: For nvme0n1 use "nvme" as argument 3
###
### Where Argument 1 is the VM type, and also the name of the output csv file with the results
### And Argument 2 is the IP address of the ncmeter receiver for the LAN test
### Argument 3 is the name of the block device being used - either "xvd", "sd" or "nvme"
###

### The instaces is expected to have 5 additional volumes attached (they will be formated and mounted by this script)
### The first additonal disk should have 300 IOPS, the second 1000, and then 5000, 10000 and 20000 in that order.


if [ $# -ne 3 ]; then
  echo "Invalid number of arguments! Three arguments needed!"
  echo "First argument is the name of the output file for the results, for example the instace type"
  echo "Second arugment is the ncmeter receiver IP address, where ncmeter is running for the LAN test"
  echo "Third argument is the block device naming being used ("xvd" or "sd")"
  echo "Example: ./script.sh t2.large 10.0.0.106"
  exit 1
fi


## Preparation and installation of packets

sudo apt-get update && apt-get upgrade -y
sudo apt-get install sysbench python bc fio -y
sudo cp /usr/share/doc/netcat-openbsd/examples/contrib/ncmeter /tmp
sudo chmod +x /tmp/ncmeter
cd /tmp
mkdir results


## Creating directories and creating/mounting additional volumes

sudo mkdir /OS-GP2
sudo mkdir /IO300
sudo mkdir /IO1K
sudo mkdir /IO5K
sudo mkdir /IO10K
sudo mkdir /IO20K


if [ $3 == "nvme" ]; then

  sudo parted /dev/nvme1n1 mklabel msdos
  sleep 1
  sudo parted /dev/nvme1n1 mkpart primary 2048s 100%
  sleep 1  
  sudo mkfs.ext4 /dev/nvme1n1p1
  sleep 1  
  sudo mount /dev/nvme1n1p1 /IO300
  sleep 1

  sudo parted /dev/nvme2n1 mklabel msdos
  sleep 1
  sudo parted /dev/nvme2n1 mkpart primary 2048s 100%
  sleep 1
  sudo mkfs.ext4 /dev/nvme2n1p1
  sleep 1
  sudo mount /dev/nvme2n1p1 /IO1K
  sleep 1

  sudo parted /dev/nvme3n1 mklabel msdos
  sleep 1
  sudo parted /dev/nvme3n1 mkpart primary 2048s 100%
  sleep 1
  sudo mkfs.ext4 /dev/nvme3n1p1
  sleep 1
  sudo mount /dev/nvme3n1p1 /IO5K
  sleep 1

  sudo parted /dev/nvme4n1 mklabel msdos
  sleep 1
  sudo parted /dev/nvme4n1 mkpart primary 2048s 100%
  sleep 1
  sudo mkfs.ext4 /dev/nvme4n1p1
  sleep 1
  sudo mount /dev/nvme4n1p1 /IO10K
  sleep 1

  sudo parted /dev/nvme5n1 mklabel msdos
  sleep 1
  sudo parted /dev/nvme5n1 mkpart primary 2048s 100%
  sleep 1
  sudo mkfs.ext4 /dev/nvme5n1p1
  sleep 1
  sudo mount /dev/nvme5n1p1 /IO20K
  sleep 1

else

  sudo parted /dev/$3b mklabel msdos
  sudo parted /dev/$3b mkpart primary 2048s 100%
  sudo mkfs.ext4 /dev/$3b1
  sudo mount /dev/$3b1 /IO300

  sudo parted /dev/$3c mklabel msdos
  sudo parted /dev/$3c mkpart primary 2048s 100%
  sudo mkfs.ext4 /dev/$3c1
  sudo mount /dev/$3c1 /IO1K

  sudo parted /dev/$3d mklabel msdos
  sudo parted /dev/$3d mkpart primary 2048s 100%
  sudo mkfs.ext4 /dev/$3d1
  sudo mount /dev/$3d1 /IO5K

  sudo parted /dev/$3e mklabel msdos
  sudo parted /dev/$3e mkpart primary 2048s 100%
  sudo mkfs.ext4 /dev/$3e1
  sudo mount /dev/$3e1 /IO10K

  sudo parted /dev/$3f mklabel msdos
  sudo parted /dev/$3f mkpart primary 2048s 100%
  sudo mkfs.ext4 /dev/$3f1
  sudo mount /dev/$3f1 /IO20K

fi

### MySQL Installation

export DEBIAN_FRONTEND=noninteractive

MYSQL_ROOT_PASSWORD='root'

# Install MySQL
echo debconf mysql-server/root_password password $MYSQL_ROOT_PASSWORD | sudo debconf-set-selections
echo debconf mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD | sudo debconf-set-selections
sudo apt-get -qq install mysql-server > /dev/null # Install MySQL quietly

# Install Expect
sudo apt-get -qq install expect > /dev/null

# Build Expect script
tee ~/secure_our_mysql.sh > /dev/null << EOF
spawn $(which mysql_secure_installation)

expect "Enter password for user root:"
send "$MYSQL_ROOT_PASSWORD\r"

expect "Press y|Y for Yes, any other key for No:"
send "y\r"

expect "Please enter 0 = LOW, 1 = MEDIUM and 2 = STRONG:"
send "2\r"

expect "Change the password for root ? ((Press y|Y for Yes, any other key for No) :"
send "n\r"

expect "Remove anonymous users? (Press y|Y for Yes, any other key for No) :"
send "y\r"

expect "Disallow root login remotely? (Press y|Y for Yes, any other key for No) :"
send "y\r"

expect "Remove test database and access to it? (Press y|Y for Yes, any other key for No) :"
send "y\r"

expect "Reload privilege tables now? (Press y|Y for Yes, any other key for No) :"
send "y\r"

EOF

# This runs the "mysql_secure_installation" script which removes insecure defaults.
sudo expect ~/secure_our_mysql.sh

# Cleanup
rm -v ~/secure_our_mysql.sh # Remove the generated Expect script

# Create "test" database that is needed for the MySQL test
mysql -u root -proot -e "CREATE DATABASE test;"



### Testing


# SpeedTest:

sudo curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python - >> /tmp/results/out.speedtest 2>&1


# LAN:
# Change to target the reciever machine by using second argument in the script ($2)

#./ncmeter $2 256M >> /tmp/results/out.lan 2>&1
iperf -c $2 -i 5 -t 30 >> /tmp/results/out.lan 2>&1


# Packets per second

#ping -c 20000 -q -s 1 -f $2 >>  /tmp/results/out.packets
/tmp/bonesi/src/bonesi $2:80 -p icmp -c 1000000 >>  /tmp/results/out.packets


#CPU:

# Test with 1 core, maximum number of core, and double the number of cores

CORES=$(cat /proc/cpuinfo | grep processor | wc -l)

sudo sysbench --test=cpu --num-threads=1 --cpu-max-prime=10000 run >>/tmp/results/out.cpu1-10k 2>&1
sudo sysbench --test=cpu --num-threads=$CORES --cpu-max-prime=10000 run >>/tmp/results/out.cpuMax-10k 2>&1
sudo sysbench --test=cpu --num-threads=$(($CORES*2)) --cpu-max-prime=10000 run >>/tmp/results/out.cpuDouble-10k 2>&1
sudo sysbench --test=cpu --num-threads=1 --cpu-max-prime=20000 run >>/tmp/results/out.cpu1-20k 2>&1
sudo sysbench --test=cpu --num-threads=$CORES --cpu-max-prime=20000 run >>/tmp/results/out.cpuMax-20k 2>&1
sudo sysbench --test=cpu --num-threads=$(($CORES*2)) --cpu-max-prime=20000 run >>/tmp/results/out.cpuDouble-20k 2>&1


# DISK:

sudo fio --directory=/OS-GP2 --name fio_test_file --direct=1 --rw=randwrite --bs=4k --size=1G --numjobs=16 --time_based --runtime=180 --group_reporting --norandommap >> /tmp/results/out.disk-os-gp2-fio-write
sudo fio --directory=/OS-GP2 --name fio_test_file  --direct=1 --rw=randread --bs=4k --size=1G --numjobs=16 --time_based --runtime=180 --group_reporting --norandommap >> /tmp/results/out.disk-os-gp2-fio-read
sudo fio --directory=/IO300 --name fio_test_file --direct=1 --rw=randwrite --bs=4k --size=1G --numjobs=16 --time_based --runtime=180 --group_reporting --norandommap >> /tmp/results/out.disk-io300-fio-write
sudo fio --directory=/IO300 --name fio_test_file  --direct=1 --rw=randread --bs=4k --size=1G --numjobs=16 --time_based --runtime=180 --group_reporting --norandommap >> /tmp/results/out.disk-io300-fio-read
sudo fio --directory=/IO1K --name fio_test_file --direct=1 --rw=randwrite --bs=4k --size=1G --numjobs=16 --time_based --runtime=180 --group_reporting --norandommap >> /tmp/results/out.disk-io1k-fio-write
sudo fio --directory=/IO1K --name fio_test_file  --direct=1 --rw=randread --bs=4k --size=1G --numjobs=16 --time_based --runtime=180 --group_reporting --norandommap >> /tmp/results/out.disk-io1k-fio-read
sudo fio --directory=/IO5K --name fio_test_file --direct=1 --rw=randwrite --bs=4k --size=1G --numjobs=16 --time_based --runtime=180 --group_reporting --norandommap >> /tmp/results/out.disk-io5k-fio-write
sudo fio --directory=/IO5K --name fio_test_file  --direct=1 --rw=randread --bs=4k --size=1G --numjobs=16 --time_based --runtime=180 --group_reporting --norandommap >> /tmp/results/out.disk-io5k-fio-read
sudo fio --directory=/IO10K --name fio_test_file --direct=1 --rw=randwrite --bs=4k --size=1G --numjobs=16 --time_based --runtime=180 --group_reporting --norandommap >> /tmp/results/out.disk-io10k-fio-write
sudo fio --directory=/IO10K --name fio_test_file  --direct=1 --rw=randread --bs=4k --size=1G --numjobs=16 --time_based --runtime=180 --group_reporting --norandommap >> /tmp/results/out.disk-io10k-fio-read
sudo fio --directory=/IO20K --name fio_test_file --direct=1 --rw=randwrite --bs=4k --size=1G --numjobs=16 --time_based --runtime=180 --group_reporting --norandommap >> /tmp/results/out.disk-io20k-fio-write
sudo fio --directory=/IO20K --name fio_test_file  --direct=1 --rw=randread --bs=4k --size=1G --numjobs=16 --time_based --runtime=180 --group_reporting --norandommap >> /tmp/results/out.disk-io20k-fio-read


if [ $3 == "nvme" ]; then

  sudo hdparm -t /dev/nvme0n1p1 >> /tmp/results/out.disk-os-gp2-io-bandwidth 2>&1
  sudo hdparm -t /dev/nvme1n1p1 >> /tmp/results/out.disk-io300-io-bandwidth 2>&1
  sudo hdparm -t /dev/nvme2n1p1 >> /tmp/results/out.disk-io1k-io-bandwidth 2>&1
  sudo hdparm -t /dev/nvme3n1p1 >> /tmp/results/out.disk-io5k-io-bandwidth 2>&1
  sudo hdparm -t /dev/nvme4n1p1 >> /tmp/results/out.disk-io10k-io-bandwidth 2>&1
  sudo hdparm -t /dev/nvme5n1p1 >> /tmp/results/out.disk-io20k-io-bandwidth 2>&1

fi

if [ $3 == "xvd" ]; then

  sudo hdparm -t /dev/xvda1 >> /tmp/results/out.disk-os-gp2-io-bandwidth 2>&1
  sudo hdparm -t /dev/xvdb1 >> /tmp/results/out.disk-io300-io-bandwidth 2>&1
  sudo hdparm -t /dev/xvdc1 >> /tmp/results/out.disk-io1k-io-bandwidth 2>&1
  sudo hdparm -t /dev/xvdd1 >> /tmp/results/out.disk-io5k-io-bandwidth 2>&1
  sudo hdparm -t /dev/xvde1 >> /tmp/results/out.disk-io10k-io-bandwidth 2>&1
  sudo hdparm -t /dev/xvdf1 >> /tmp/results/out.disk-io20k-io-bandwidth 2>&1

fi

if [ $3 == "sd" ]; then

  sudo hdparm -t /dev/sda1 >> /tmp/results/out.disk-os-gp2-io-bandwidth 2>&1
  sudo hdparm -t /dev/sdb1 >> /tmp/results/out.disk-io300-io-bandwidth 2>&1
  sudo hdparm -t /dev/sdc1 >> /tmp/results/out.disk-io1k-io-bandwidth 2>&1
  sudo hdparm -t /dev/sdd1 >> /tmp/results/out.disk-io5k-io-bandwidth 2>&1
  sudo hdparm -t /dev/sde1 >> /tmp/results/out.disk-io10k-io-bandwidth 2>&1
  sudo hdparm -t /dev/sdf1 >> /tmp/results/out.disk-io20k-io-bandwidth 2>&1

fi

# MySQL Test: (root, with password root, and database "test")

sudo sysbench --test=oltp --oltp-table-size=1000000 --db-driver=mysql --mysql-db=test --mysql-user=root --mysql-password=root prepare
sudo sysbench --test=oltp --oltp-table-size=1000000 --db-driver=mysql --mysql-db=test --mysql-user=root --mysql-password=root --max-time=60 --oltp-read-only=on --max-requests=0 --num-threads=8 run >> /tmp/results/out.mysql


# RAM:

sudo mkdir /tmp/TEST_RAM
sudo mount tmpfs -t tmpfs /tmp/TEST_RAM 2>/dev/null
sudo dd if=/dev/zero of=/tmp/TEST_RAM/data_tmp bs=1M count=512 >> /tmp/results/out.mem-write 2>&1
sudo dd if=/tmp/TEST_RAM/data_tmp of=/dev/null bs=1M count=512 >> /tmp/results/out.mem-read 2>&1



## Prep for parsing

CPU_MODEL=$(cat /proc/cpuinfo | grep "model name" | cut -d ':' -f2 | sed 's/^ *//' | uniq)
CPU_TIME_1_10K=$(cat /tmp/results/out.cpu1-10k | grep "total time:" | awk '{print $3}')
CPU_TIME_MAX_10K=$(cat /tmp/results/out.cpuMax-10k | grep "total time:" | awk '{print $3}')
CPU_TIME_DOUBLE_10K=$(cat /tmp/results/out.cpuDouble-10k| grep "total time:" | awk '{print $3}')
CPU_TIME_1_20K=$(cat /tmp/results/out.cpu1-20k | grep "total time:" | awk '{print $3}')
CPU_TIME_MAX_20K=$(cat /tmp/results/out.cpuMax-20k | grep "total time:" | awk '{print $3}')
CPU_TIME_DOUBLE_20K=$(cat /tmp/results/out.cpuDouble-20k | grep "total time:" | awk '{print $3}')

RAM_TOTAL=$(cat /proc/meminfo | grep "MemTotal" | awk '{print $2}' | awk '{$1=$1/(1024^2); print $1,"GB";}')
RAM_WRITE=$(cat /tmp/results/out.mem-write | egrep 'GB/s|MB/s' | awk '{print $10,$11}')
RAM_READ=$(cat /tmp/results/out.mem-read | egrep 'GB/s|MB/s' | awk '{print $10,$11}')

DISK_OS_GP2_IO_BANDWIDTH=$(cat /tmp/results/out.disk-os-gp2-io-bandwidth | grep "Timing" | awk '{print $11,$12}')
DISK_IO300_IO_BANDWIDTH=$(cat /tmp/results/out.disk-io300-io-bandwidth | grep "Timing" | awk '{print $11,$12}')
DISK_IO1K_IO_BANDWIDTH=$(cat /tmp/results/out.disk-io1k-io-bandwidth | grep "Timing" | awk '{print $11,$12}')
DISK_IO5K_IO_BANDWIDTH=$(cat /tmp/results/out.disk-io5k-io-bandwidth | grep "Timing" | awk '{print $11,$12}')
DISK_IO10K_IO_BANDWIDTH=$(cat /tmp/results/out.disk-io10k-io-bandwidth | grep "Timing" | awk '{print $11,$12}')
DISK_IO20K_IO_BANDWIDTH=$(cat /tmp/results/out.disk-io20k-io-bandwidth | grep "Timing" | awk '{print $11,$12}')

DISK_OS_GP2_WRITE_IO=$(cat /tmp/results/out.disk-os-gp2-fio-write | grep "write: " | awk '{print $2}' | cut -d ',' -f1 | cut -d '=' -f2)
DISK_OS_GP2_WRITE_BW=$(cat /tmp/results/out.disk-os-gp2-fio-write | grep "write: " | awk '{print $3}' | cut -d ',' -f1 | cut -d '=' -f2)
DISK_OS_GP2_WRITE_IOPS=$(cat /tmp/results/out.disk-os-gp2-fio-write | grep "write: " | awk '{print $4}' | cut -d ',' -f1 | cut -d '=' -f2)
DISK_OS_GP2_WRITE_AGGRB=$(cat /tmp/results/out.disk-os-gp2-fio-write | grep "WRITE: " | awk '{print $3}' | cut -d ',' -f1 | cut -d '=' -f2)
DISK_OS_GP2_READ_IO=$(cat /tmp/results/out.disk-os-gp2-fio-read | grep "read :" | awk '{print $3}' | cut -d ',' -f1 | cut -d '=' -f2)
DISK_OS_GP2_READ_BW=$(cat /tmp/results/out.disk-os-gp2-fio-read | grep "read : " | awk '{print $4}' | cut -d ',' -f1 | cut -d '=' -f2)
DISK_OS_GP2_READ_IOPS=$(cat /tmp/results/out.disk-os-gp2-fio-read | grep "read : " | awk '{print $5}' | cut -d ',' -f1 | cut -d '=' -f2)
DISK_OS_GP2_READ_AGGRB=$(cat /tmp/results/out.disk-os-gp2-fio-read | grep "READ: " | awk '{print $3}' | cut -d ',' -f1 | cut -d '=' -f2)

DISK_IO300_WRITE_IO=$(cat /tmp/results/out.disk-io300-fio-write | grep "write: " | awk '{print $2}' | cut -d ',' -f1 | cut -d '=' -f2)
DISK_IO300_WRITE_BW=$(cat /tmp/results/out.disk-io300-fio-write | grep "write: " | awk '{print $3}' | cut -d ',' -f1 | cut -d '=' -f2)
DISK_IO300_WRITE_IOPS=$(cat /tmp/results/out.disk-io300-fio-write | grep "write: " | awk '{print $4}' | cut -d ',' -f1 | cut -d '=' -f2)
DISK_IO300_WRITE_AGGRB=$(cat /tmp/results/out.disk-io300-fio-write | grep "WRITE: " | awk '{print $3}' | cut -d ',' -f1 | cut -d '=' -f2)
DISK_IO300_READ_IO=$(cat /tmp/results/out.disk-io300-fio-read | grep "read :" | awk '{print $3}' | cut -d ',' -f1 | cut -d '=' -f2)
DISK_IO300_READ_BW=$(cat /tmp/results/out.disk-io300-fio-read | grep "read : " | awk '{print $4}' | cut -d ',' -f1 | cut -d '=' -f2)
DISK_IO300_READ_IOPS=$(cat /tmp/results/out.disk-io300-fio-read | grep "read : " | awk '{print $5}' | cut -d ',' -f1 | cut -d '=' -f2)
DISK_IO300_READ_AGGRB=$(cat /tmp/results/out.disk-io300-fio-read | grep "READ: " | awk '{print $3}' | cut -d ',' -f1 | cut -d '=' -f2)

DISK_IO1K_WRITE_IO=$(cat /tmp/results/out.disk-io1k-fio-write | grep "write: " | awk '{print $2}' | cut -d ',' -f1 | cut -d '=' -f2)
DISK_IO1K_WRITE_BW=$(cat /tmp/results/out.disk-io1k-fio-write | grep "write: " | awk '{print $3}' | cut -d ',' -f1 | cut -d '=' -f2)
DISK_IO1K_WRITE_IOPS=$(cat /tmp/results/out.disk-io1k-fio-write | grep "write: " | awk '{print $4}' | cut -d ',' -f1 | cut -d '=' -f2)
DISK_IO1K_WRITE_AGGRB=$(cat /tmp/results/out.disk-io1k-fio-write | grep "WRITE: " | awk '{print $3}' | cut -d ',' -f1 | cut -d '=' -f2)
DISK_IO1K_READ_IO=$(cat /tmp/results/out.disk-io1k-fio-read | grep "read :" | awk '{print $3}' | cut -d ',' -f1 | cut -d '=' -f2)
DISK_IO1K_READ_BW=$(cat /tmp/results/out.disk-io1k-fio-read | grep "read : " | awk '{print $4}' | cut -d ',' -f1 | cut -d '=' -f2)
DISK_IO1K_READ_IOPS=$(cat /tmp/results/out.disk-io1k-fio-read | grep "read : " | awk '{print $5}' | cut -d ',' -f1 | cut -d '=' -f2)
DISK_IO1K_READ_AGGRB=$(cat /tmp/results/out.disk-io1k-fio-read | grep "READ: " | awk '{print $3}' | cut -d ',' -f1 | cut -d '=' -f2)

DISK_IO5K_WRITE_IO=$(cat /tmp/results/out.disk-io5k-fio-write | grep "write: " | awk '{print $2}' | cut -d ',' -f1 | cut -d '=' -f2)
DISK_IO5K_WRITE_BW=$(cat /tmp/results/out.disk-io5k-fio-write | grep "write: " | awk '{print $3}' | cut -d ',' -f1 | cut -d '=' -f2)
DISK_IO5K_WRITE_IOPS=$(cat /tmp/results/out.disk-io5k-fio-write | grep "write: " | awk '{print $4}' | cut -d ',' -f1 | cut -d '=' -f2)
DISK_IO5K_WRITE_AGGRB=$(cat /tmp/results/out.disk-io5k-fio-write | grep "WRITE: " | awk '{print $3}' | cut -d ',' -f1 | cut -d '=' -f2)
DISK_IO5K_READ_IO=$(cat /tmp/results/out.disk-io5k-fio-read | grep "read :" | awk '{print $3}' | cut -d ',' -f1 | cut -d '=' -f2)
DISK_IO5K_READ_BW=$(cat /tmp/results/out.disk-io5k-fio-read | grep "read : " | awk '{print $4}' | cut -d ',' -f1 | cut -d '=' -f2)
DISK_IO5K_READ_IOPS=$(cat /tmp/results/out.disk-io5k-fio-read | grep "read : " | awk '{print $5}' | cut -d ',' -f1 | cut -d '=' -f2)
DISK_IO5K_READ_AGGRB=$(cat /tmp/results/out.disk-io5k-fio-read | grep "READ: " | awk '{print $3}' | cut -d ',' -f1 | cut -d '=' -f2)

DISK_IO10K_WRITE_IO=$(cat /tmp/results/out.disk-io10k-fio-write | grep "write: " | awk '{print $2}' | cut -d ',' -f1 | cut -d '=' -f2)
DISK_IO10K_WRITE_BW=$(cat /tmp/results/out.disk-io10k-fio-write | grep "write: " | awk '{print $3}' | cut -d ',' -f1 | cut -d '=' -f2)
DISK_IO10K_WRITE_IOPS=$(cat /tmp/results/out.disk-io10k-fio-write | grep "write: " | awk '{print $4}' | cut -d ',' -f1 | cut -d '=' -f2)
DISK_IO10K_WRITE_AGGRB=$(cat /tmp/results/out.disk-io10k-fio-write | grep "WRITE: " | awk '{print $3}' | cut -d ',' -f1 | cut -d '=' -f2)
DISK_IO10K_READ_IO=$(cat /tmp/results/out.disk-io10k-fio-read | grep "read :" | awk '{print $3}' | cut -d ',' -f1 | cut -d '=' -f2)
DISK_IO10K_READ_BW=$(cat /tmp/results/out.disk-io10k-fio-read | grep "read : " | awk '{print $4}' | cut -d ',' -f1 | cut -d '=' -f2)
DISK_IO10K_READ_IOPS=$(cat /tmp/results/out.disk-io10k-fio-read | grep "read : " | awk '{print $5}' | cut -d ',' -f1 | cut -d '=' -f2)
DISK_IO10K_READ_AGGRB=$(cat /tmp/results/out.disk-io10k-fio-read | grep "READ: " | awk '{print $3}' | cut -d ',' -f1 | cut -d '=' -f2)

DISK_IO20K_WRITE_IO=$(cat /tmp/results/out.disk-io20k-fio-write | grep "write: " | awk '{print $2}' | cut -d ',' -f1 | cut -d '=' -f2)
DISK_IO20K_WRITE_BW=$(cat /tmp/results/out.disk-io20k-fio-write | grep "write: " | awk '{print $3}' | cut -d ',' -f1 | cut -d '=' -f2)
DISK_IO20K_WRITE_IOPS=$(cat /tmp/results/out.disk-io20k-fio-write | grep "write: " | awk '{print $4}' | cut -d ',' -f1 | cut -d '=' -f2)
DISK_IO20K_WRITE_AGGRB=$(cat /tmp/results/out.disk-io20k-fio-write | grep "WRITE: " | awk '{print $3}' | cut -d ',' -f1 | cut -d '=' -f2)
DISK_IO20K_READ_IO=$(cat /tmp/results/out.disk-io20k-fio-read | grep "read :" | awk '{print $3}' | cut -d ',' -f1 | cut -d '=' -f2)
DISK_IO20K_READ_BW=$(cat /tmp/results/out.disk-io20k-fio-read | grep "read : " | awk '{print $4}' | cut -d ',' -f1 | cut -d '=' -f2)
DISK_IO20K_READ_IOPS=$(cat /tmp/results/out.disk-io20k-fio-read | grep "read : " | awk '{print $5}' | cut -d ',' -f1 | cut -d '=' -f2)
DISK_IO20K_READ_AGGRB=$(cat /tmp/results/out.disk-io20k-fio-read | grep "READ: " | awk '{print $3}' | cut -d ',' -f1 | cut -d '=' -f2)

DOWNLOAD=$(cat /tmp/results/out.speedtest |grep Download | awk '{print $2,$3}')
UPLOAD=$(cat /tmp/results/out.speedtest |grep Upload | awk '{print $2,$3}')

#LAN="$(cat /tmp/results/out.lan | grep MByte | awk '{print $4}'| tr -d "-") MB/s"
LAN=$(cat /tmp/results/out.lan | tail -1 | awk '{print $7,$8}')

#PACKETS_TIME=$(cat /tmp/results/out.packets |grep time | awk '{print $10}' | tr -d a-z)
#PPS="$(echo 20000/$PACKETS_TIME*1000| bc -l | cut -d '.' -f1) pps"
PPS="$(cat /tmp/results/out.packets | grep "packets in" | head -1 | awk '{print $1}') pps"

MYSQL=$(cat /tmp/results/out.mysql | grep -i "transactions:" | awk '{print $3,$4,$5}' | tr -d '(' | tr -d ')')

# Parsing and creating the csv file

echo \"VM Type\", \"CPU Model\", \"CPU Cores\", \"RAM Total\", \"CPU-1Core-10K\", \"CPU-MaxCore-10K\", \"CPU-DoubleCore-10K\", \"CPU-1Core-20K\", \"CPU-MaxCore-20K\", \"CPU-DoubleCore-20K\", \"RAM-Write\", \"RAM-Read\", \"DISK-IO-Bandwidth-OS-GP2\", \"DISK-IO-Bandwidth-IO300\", \"DISK-IO-Bandwidth-IO1K\", \"DISK-IO-Bandwidth-IO5K\", \"DISK-IO-Bandwidth-IO10K\", \"DISK-IO-Bandwidth-I20K\", \"DISK-OS-GP2-WRITE-IO\", \"DISK-OS-GP2-WRITE-BW\", \"DISK-OS-GP2-WRITE-IOPS\", \"DISK-OS-GP2-WRITE-AGGRB\", \"DISK-OS-GP2-READ-IO\", \"DISK-OS-GP2-READ-BW\", \"DISK-OS-GP2-READ-IOPS\", \"DISK-OS-GP2-READ-AGGRB\", \"DISK-IO300-WRITE-IO\", \"DISK-IO300-WRITE-BW\", \"DISK-IO300-WRITE-IOPS\", \"DISK-IO300-WRITE-AGGRB\", \"DISK-IO300-READ-IO\", \"DISK-IO300-READ-BW\", \"DISK-IO300-READ-IOPS\", \"DISK-IO300-READ-AGGRB\", \"DISK-IO1K-WRITE-IO\", \"DISK-IO1K-WRITE-BW\", \"DISK-IO1K-WRITE-IOPS\", \"DISK-IO1K-WRITE-AGGRB\", \"DISK-IO1K-READ-IO\", \"DISK-IO1K-READ-BW\", \"DISK-IO1K-READ-IOPS\", \"DISK-IO1K-READ-AGGRB\", \"DISK-IO5K-WRITE-IO\", \"DISK-IO5K-WRITE-BW\", \"DISK-IO5K-WRITE-IOPS\", \"DISK-IO5K-WRITE-AGGRB\", \"DISK-IO5K-READ-IO\", \"DISK-IO5K-READ-BW\", \"DISK-IO5K-READ-IOPS\", \"DISK-IO5K-READ-AGGRB\", \"DISK-IO10K-WRITE-IO\", \"DISK-IO10K-WRITE-BW\", \"DISK-IO10K-WRITE-IOPS\", \"DISK-IO10K-WRITE-AGGRB\", \"DISK-IO10K-READ-IO\", \"DISK-IO10K-READ-BW\", \"DISK-IO10K-READ-IOPS\", \"DISK-IO10K-READ-AGGRB\", \"DISK-IO20K-WRITE-IO\", \"DISK-IO20K-WRITE-BW\", \"DISK-IO20K-WRITE-IOPS\", \"DISK-IO20K-WRITE-AGGRB\", \"DISK-IO20K-READ-IO\", \"DISK-IO20K-READ-BW\", \"DISK-IO20K-READ-IOPS\", \"DISK-IO20K-READ-AGGRB\", \"WAN-Download\", \"WAN-Upload\", \"LAN\", \"Packets\", \"MySQL\" >> /tmp/$1.csv
echo \"$1\", \"$CPU_MODEL\", \"$CORES\", \"$RAM_TOTAL\", \"$CPU_TIME_1_10K\", \"$CPU_TIME_MAX_10K\", \"$CPU_TIME_DOUBLE_10K\", \"$CPU_TIME_1_20K\", \"$CPU_TIME_MAX_20K\", \"$CPU_TIME_DOUBLE_20K\", \"$RAM_WRITE\", \"$RAM_READ\", \"$DISK_OS_GP2_IO_BANDWIDTH\", \"$DISK_IO300_IO_BANDWIDTH\", \"$DISK_IO1K_IO_BANDWIDTH\", \"$DISK_IO5K_IO_BANDWIDTH\", \"$DISK_IO10K_IO_BANDWIDTH\", \"$DISK_IO10K_IO_BANDWIDTH\", \"$DISK_OS_GP2_WRITE_IO\", \"$DISK_OS_GP2_WRITE_BW\", \"$DISK_OS_GP2_WRITE_IOPS\", \"$DISK_OS_GP2_WRITE_AGGRB\", \"$DISK_OS_GP2_READ_IO\", \"$DISK_OS_GP2_READ_BW\", \"$DISK_OS_GP2_READ_IOPS\", \"$DISK_OS_GP2_READ_AGGRB\", \"$DISK_IO300_WRITE_IO\", \"$DISK_IO300_WRITE_BW\", \"$DISK_IO300_WRITE_IOPS\", \"$DISK_IO300_WRITE_AGGRB\", \"$DISK_IO300_READ_IO\", \"$DISK_IO300_READ_BW\", \"$DISK_IO300_READ_IOPS\", \"$DISK_IO300_READ_AGGRB\", \"$DISK_IO1K_WRITE_IO\", \"$DISK_IO1K_WRITE_BW\", \"$DISK_IO1K_WRITE_IOPS\", \"$DISK_IO1K_WRITE_AGGRB\", \"$DISK_IO1K_READ_IO\", \"$DISK_IO1K_READ_BW\", \"$DISK_IO1K_READ_IOPS\", \"$DISK_IO1K_READ_AGGRB\", \"$DISK_IO5K_WRITE_IO\", \"$DISK_IO5K_WRITE_BW\", \"$DISK_IO5K_WRITE_IOPS\", \"$DISK_IO5K_WRITE_AGGRB\", \"$DISK_IO5K_READ_IO\", \"$DISK_IO5K_READ_BW\", \"$DISK_IO5K_READ_IOPS\", \"$DISK_IO5K_READ_AGGRB\", \"$DISK_IO10K_WRITE_IO\", \"$DISK_IO10K_WRITE_BW\", \"$DISK_IO10K_WRITE_IOPS\", \"$DISK_IO10K_WRITE_AGGRB\", \"$DISK_IO10K_READ_IO\", \"$DISK_IO10K_READ_BW\", \"$DISK_IO10K_READ_IOPS\", \"$DISK_IO10K_READ_AGGRB\", \"$DISK_IO20K_WRITE_IO\", \"$DISK_IO20K_WRITE_BW\", \"$DISK_IO20K_WRITE_IOPS\", \"$DISK_IO20K_WRITE_AGGRB\", \"$DISK_IO20K_READ_IO\", \"$DISK_IO20K_READ_BW\", \"$DISK_IO20K_READ_IOPS\", \"$DISK_IO20K_READ_AGGRB\", \"$DOWNLOAD\", \"$UPLOAD\", \"$LAN\",\"$PPS\", \"$MYSQL\" >> /tmp/$1.csv
