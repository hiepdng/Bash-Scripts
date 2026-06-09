#!/bin/bash
# Hiep, 08/18/2025
# This script is used to
#  -Display disks and partitions information
#  -Backup: .Volume Group configuration
#           .backup partition table using "dd" and "sfdisk" commands
#           .root (/) partition using fsarchiver
#           ./boot partition using fsarchiver
#           ./boot/efi partition (if existed) using fsarchiver
#  -Print out commands how to restore root (/), /boot and /boot/efi patitions
#  -print out commands how to create pv, vg and lv
#  -Print out command how to restore vg from a configuration file
#
# Usage:
# # bash ./disk_info.sh &> ./disk_info.log          <-use bash instead of sh or nothing
#
##############################################################################

DATE=`date +%y%m%d`
HOSTNAME=`hostname -s`
mkdir -p ${HOSTNAME}_system_bk_${DATE}
cd ${HOSTNAME}_system_bk_${DATE}
#FSARCHIVER_PATH="/home/src/fsarchiver/sbin"
FSARCHIVER_PATH="/usr/sbin"
#FSARCHIVER_PATH="/nfs/sheep_home/src/fsarchiver/sbin"



/usr/bin/echo -e "====================================================================="
/usr/bin/echo -e "System information:\n"
/usr/bin/echo -e "\n\$ cat /etc/os-release ---------------------------"
/usr/bin/cat /etc/os-release
/usr/bin/echo

/usr/bin/echo -e "\n\$ uname -a ---------------------------"
/usr/bin/uname -a


/usr/bin/echo -e "\n\n=================================================================="
/usr/bin/echo -e "Disks Storage Information:"

/usr/bin/echo -e "\n\$ lsblk -f ---------------------------"
/usr/bin/lsblk -f

/usr/bin/echo -e "\n\$ blkid ---------------------------"
/usr/sbin/blkid

/usr/bin/echo -e "\n\$ pvs --------------------------------"
/usr/sbin/pvs

/usr/bin/echo -e "\n\$ pvdisplay --------------------------"
/usr/sbin/pvdisplay

/usr/bin/echo -e "\n\$ vgs --------------------------------"
/usr/sbin/vgs

/usr/bin/echo -e "\n\$ vgdisplay --------------------------"
/usr/sbin/vgdisplay
   
/usr/bin/echo -e "\n\$ lvs --------------------------------"
/usr/sbin/lvs

/usr/bin/echo -e "\n\$ lvdisplay --------------------------"
/usr/sbin/lvdisplay

/usr/bin/echo -e "\n\$ sfdisk -l /dev/sdX -----------------"
for I in `ls -1 /dev/|grep  sd |grep -v sd.[0-9]`; do sfdisk -l /dev/$I && /usr/bin/echo && /usr/bin/echo "---"; done

/usr/bin/echo -e "\n\$ df -Th -----------------------------"
/usr/bin/df -Th

/usr/bin/echo -e "\n\$ mount | grep "^/dev" ---------------"
/usr/bin/mount | grep "^/dev"

/usr/bin/echo -e "\n\$ cat /etc/fstab ---------------------"
/usr/bin/cat /etc/fstab

/usr/bin/echo -e "\n\$ parted -l --------------------------"
/usr/sbin/parted -l




/usr/bin/echo -e "\n\n=================================================================="
/usr/bin/echo -e "Backing up:"

###auto detect the boot device
#DEVICE_PATH=$(sfdisk -l |grep ^/dev | grep -F \*| cut -d " " -f 1)  #find boot partition: /dev/sda1
#DEVICE_PATH=${DEVICE_PATH::-1}                                      #remove the last character: /dev/sda

#DEVICE_PATH=$(df /boot |tail -1 |awk '{print $1}' | sed 's/.$//')    #find boot partition
#DEVICE_NAME=$(echo $DEVICE_PATH |cut -d / -f 3)

DEVICE_NAME=$(lsblk --list -no type,name --inverse $(findmnt -nvoSOURCE -T "/boot") | grep ^disk | awk '{ print $2 }' | head -1)
DEVICE_PATH=/dev/$DEVICE_NAME




/usr/bin/echo -e "\n-Backing up partition table ---------------------"
/usr/bin/echo -e "\$ dd if=$DEVICE_PATH of=$DEVICE_NAME.mbr count=1 bs=512"
/usr/bin/dd if=$DEVICE_PATH of=$DEVICE_NAME.mbr count=1 bs=512

/usr/bin/echo -e "\n\$ sfdisk -d $DEVICE_PATH > $DEVICE_NAME.sf "
/usr/sbin/sfdisk -d $DEVICE_PATH > $DEVICE_NAME.sf


/usr/bin/echo -e "\n\n-Volume Group configuration backup --------------"
/usr/bin/echo -e "\$ vgcfgbackup"
/usr/sbin/vgcfgbackup

/usr/bin/echo -e "\n\$ cp /etc/lvm/backup/* ."
/usr/bin/cp /etc/lvm/backup/* .


/usr/bin/echo -e "\n\n-Backing up partitions root (/), /boot, /boot/efi ---------------------"
IFS=$'\n'
for LINE in `df`; do
  MOUNT_POINT=`/usr/bin/echo $LINE | awk '{print $NF}'`

  if [[ $MOUNT_POINT == "/" ]]; then
    PARTITION=`/usr/bin/echo $LINE | awk '{print $1}'`
    FILENAME=`/usr/bin/echo $PARTITION |sed -e "s/\//./g"`
    FILENAME=${FILENAME:1}
    FILENAME+="_root"
    /usr/bin/echo -e ".Backup $PARTITION = / partition"
    /usr/bin/echo -e "\$ fsarchiver savefs $FILENAME.fsa $PARTITION -A            <==backup partition"
    /usr/bin/echo -e "\$ fsarchiver restfs $FILENAME.fsa id=0,dest=$PARTITION -A  <==restore partition"
    /usr/bin/echo -e "(This command is for your future restoration.)"
    /usr/bin/echo -e "Running..."
    /usr/bin/echo -e "fsarchiver savefs $FILENAME.fsa $PARTITION -A"
    $FSARCHIVER_PATH/fsarchiver savefs $FILENAME.fsa $PARTITION -A
  fi

  if [[ $MOUNT_POINT == "/boot" ]]; then
    PARTITION=`/usr/bin/echo $LINE | awk '{print $1}'`
    FILENAME=`/usr/bin/echo $PARTITION |sed -e "s/\//./g"`
    FILENAME=${FILENAME:1}
    FILENAME+="_boot"
    /usr/bin/echo -e "\n.Backup $PARTITION = /boot partition"
    /usr/bin/echo -e "\$ fsarchiver savefs $FILENAME.fsa $PARTITION -A            <==backup partition"
    /usr/bin/echo -e "\$ fsarchiver restfs $FILENAME.fsa id=0,dest=$PARTITION -A  <==restore partition"
    /usr/bin/echo -e "(This command is for your future restoration.)"
    /usr/bin/echo -e "Running..."
    /usr/bin/echo "fsarchiver savefs $FILENAME.fsa $PARTITION -A"
    $FSARCHIVER_PATH/fsarchiver savefs $FILENAME.fsa $PARTITION -A

  fi

  if [[ $MOUNT_POINT == "/boot/efi" ]]; then
    PARTITION=`/usr/bin/echo $LINE | awk '{print $1}'`
    FILENAME=`/usr/bin/echo $PARTITION |sed -e "s/\//./g"`
    FILENAME=${FILENAME:1}
    FILENAME+="_boot-efi"
    /usr/bin/echo -e "\n.Backup $PARTITION = /boot/efi partition"
    /usr/bin/echo -e "\$ fsarchiver savefs $FILENAME.fsa $PARTITION -A              <==backup partition"
    /usr/bin/echo -e "\$ fsarchiver restfs $FILENAME.fsa id=0,dest=$PARTITION -A    <==restore partition"
    /usr/bin/echo -e "(This command is for your future restoration.)"
    /usr/bin/echo -e "Running..."
    /usr/bin/echo "fsarchiver savefs $FILENAME.fsa $PARTITION -A"
    $FSARCHIVER_PATH/fsarchiver savefs $FILENAME.fsa $PARTITION -A
  fi
done
unset IFS




/usr/bin/echo -e "\n\n\n=================================================================="
/usr/bin/echo "Example commands for your future restoration:"

/usr/bin/echo -e "\nBoot your machine using SystemRecueCD to run the below commands:    ***"

/usr/bin/echo -e "\n-Restore partition table: ---------------------"
/usr/bin/echo -e "\$ dd if=sda.mbr of=/dev/sda bs=512 count=1"
/usr/bin/echo -e "\$ sfdisk /dev/sda < sda.sf"
/usr/bin/echo -e "Note: .You only need to restore the partition table if the" 
/usr/bin/echo -e "       replacement disk is the same as the old one."
/usr/bin/echo -e "      .You don't even need to restore the partition table"
/usr/bin/echo -e "       even if the new and the old dsiks are the same size of not."

/usr/bin/echo -e "\n-Checking disks: ---------------------"
/usr/bin/echo -e "\$ parted -l"
/usr/bin/echo -e "\$ parted /dev/sda print"
/usr/bin/echo -e "\$ lsblk -f"

/usr/bin/echo -e "\n-Create a new partition table: partition ----------------"
/usr/bin/echo -e "\$ parted -s -a optimal /dev/sda -- mklabel gpt \\          <-for gpt"
/usr/bin/echo -e "          mkpart primary xfs 0% 2GiB name '1' \\      <-/boot partition"
/usr/bin/echo -e "          mkpart primary     2GiB 100% name '2'      <-lvm partition"
/usr/bin/echo -e "Or"
/usr/bin/echo -e "\$ parted -s -a optimal /dev/sda -- mklabel msdos \\        <-for msdos"
/usr/bin/echo -e "          mkpart primary xfs 0% 2GiB \\"
/usr/bin/echo -e "          mkpart primary     2GiB 100%"
/usr/bin/echo -e "   Where:"
/usr/bin/echo -e "     (This is for gpt/msdos partition table:)"
/usr/bin/echo -e "     maklabel: gpt, msdos, loop"
/usr/bin/echo -e "     part-type: primary/logical/extended"
/usr/bin/echo -e "     fs_type: ext4, fat16, fat32, linux-swap, ntfs, xfs (optional)"
/usr/bin/echo -e "     start-end: 0% 20480MB"
/usr/bin/echo -e "     name: '1' (name partition NUMBER as NAME: only for gpt)"

/usr/bin/echo -e "\n-Set flag on: partition 1 and 2 ----------------"
/usr/bin/echo -e "\$ parted -s /dev/sda -- set 1 boot on       <-set label first partition"
/usr/bin/echo -e "\$ parted -s /dev/sda -- set 2 lvm on        <-set lable second partition"

/usr/bin/echo -e "\n-Format partition 1 as xfs for /boot"
/usr/bin/echo -e "\$ mkfs.xfs /dev/sda1 -L boot -m uuid=9dbe0de8-6fa3-4d95-9553-26768793e252"
/usr/bin/echo -e "\$ xfs_admin -U  9dbe0de8-6fa3-4d95-9553-26768793e252 /dev/sda1"
/usr/bin/echo -e "  (change UUID if it is not done)"

/usr/bin/echo -e "\n-Create Physical Volume on partition 2: ----------------------"
/usr/bin/echo -e "\$ pvcreate /dev/sda2"
/usr/bin/echo -e "or"
/usr/bin/echo -e "\$ pvcreate --norestorefile -u oUA5jA-Qd24-HAbI-ye2s-v1WG-wYc6-LDv8MJ /dev/sda2 -ff"
/usr/bin/echo -e "(Create pv with the original uuid listed with the \"lsblk -f\" command above.)"

/usr/bin/echo -e "\n-Restore Volume Group: (optional) ------------------------"
/usr/bin/echo -e "\$ vgcfgrestore VG1 --test -f VG1.conf             <-just for testing"
/usr/bin/echo -e "\$ vgcfgrestore VG1 -f VG1.conf                    <-real restore"
/usr/bin/echo -e "  (Restore VG configuration from the vg config file."
/usr/bin/echo -e "  You don't need to create vg and lv below.)"
/usr/bin/echo -e "  Note:"
/usr/bin/echo -e "    You need to edit the VG1.conf to use the correct physical device   ***"
/usr/bin/echo -e "    (such as/dev/sda2 or /dev/sdc2, etc.)"

/usr/bin/echo -e "\n-Create Volume Group: -------------------------"
/usr/bin/echo -e "\$ vgcreate VG1 /dev/sda2"
/usr/bin/echo -e " Volume Group Name: VG1"
/usr/bin/echo -e " Note: use the correct vg name from vgs command above."

/usr/bin/echo -e "\n-Create Logical Volumes: ----------------------"
/usr/bin/echo -e "\$ lvcreate -n root -l EXTENDS VG1"
/usr/bin/echo -e "                   -L xxGB    VG1"
/usr/bin/echo -e "\$ lvcreate -n swap -l EXTENDS VG1"
/usr/bin/echo -e "                   -L xxGB    VG1"
/usr/bin/echo -e "\$ lvcreate -n home -l EXTENDS VG1"
/usr/bin/echo -e "                   -L xxGB    VG1"
/usr/bin/echo -e "  .Where: EXTENDS = Current_LE value (the number of current logical extends)"
/usr/bin/echo -e "          xxGB    = LV_Size          (partition size such as 25GB, 8GB, 300GB)"
/usr/bin/echo -e "          in the result of \"lvdisplay\" commands above."
/usr/bin/echo -e "  .Note: If the new disk has different size than the old disk,"
/usr/bin/echo -e "         the size of /home will be set different than the original."

/usr/bin/echo -e "\n-Activate Volume Group --------------------"
/usr/bin/echo -e "\$ lvchange -a y VG1"
/usr/bin/echo -e "  (vchange -a n VG1    <-deactivate vg)" 

/usr/bin/echo -e "\n-Format partition if you do not restore from a backup image ---------"
/usr/bin/echo -e "\$ mkfs.xfs /dev/VG1/root"
/usr/bin/echo -e "\$ mkswap /dev/VG1/swap "
/usr/bin/echo -e "\$ mkfs.xfs /dev/VG1/home"
/usr/bin/echo -e "\$ xfs_admin -U 45708768-e007-47a0-a347-52b6e3b8a191 /dev/VG1/root"
/usr/bin/echo -e "\$ swaplabel -U 4b100c75-abf8-4481-979b-d23cd20062ab /dev/VG1/swap"
/usr/bin/echo -e "\$ xfs_admin -U 4e4635a7-6fd1-447c-92c3-a795824568bc /dev/mapper/VG1-home"
/usr/bin/echo -e "\$ xfs_admin -L home /dev/mapper/VG1-root |"
/usr/bin/echo -e "\$ swaplabel -L swap /dev/mapper/VG1-swap |  <-label root, swap, home"
/usr/bin/echo -e "\$ xfs_admin -L home /dev/mapper/VG1-home |"
/usr/bin/echo -e "or"
/usr/bin/echo -e "\$ mkfs.xfs -f /dev/mapper/VG1-root -L root -m uuid=xxx  |"
/usr/bin/echo -e "\$ mkswap /dev/mapper/VG1-swap -L swap -U uuid           |   <-I use this  ***"
/usr/bin/echo -e "\$ mkfs.xfs -f /dev/mapper/VG1-home -L home -m uuid=xxx  |"
/usr/bin/echo -e "(uuid=uuid from \"lsblk -f\" command above)"

/usr/bin/echo -e "\n\n-Or with /boot/efi partition:"
/usr/bin/echo -e "\$ parted -s -a optimal /dev/sda -- mklabel gpt \\"
/usr/bin/echo -e "          mkpart primary fat16 0% 1GiB name '1' \\      <-/boot/efi partition"
/usr/bin/echo -e "          mkpart primary xfs 1GiB 3GiB name '2' \\      <-/boot partition"
/usr/bin/echo -e "          mkpart primary     3GiB 100% name '3'        <-lvm partition"
/usr/bin/echo -e "\$ parted -s /dev/sda -- set 1 boot on                  <-/boot/efi partition"
/usr/bin/echo -e "\$ parted -s /dev/sda -- set 3 lvm on                   <-lvm partition"
/usr/bin/echo -e "\$ mkfs.fat /dev/sda1 -n efi"
/usr/bin/echo -e "\$ mkfs.xfs /dev/sda2 -L boot -m uuid=xxx"
/usr/bin/echo -e "\$ pvcreate --norestorefile -u oUA5jA-Qd24-HAbI-ye2s-v1WG-wYc6-LDv8MJ /dev/sda3 -ff"
/usr/bin/echo -e "\$ vgcreate VG1 /dev/sda3"
/usr/bin/echo -e "\$ lvcreate -n root -l CURRENT_LE_for_root VG1"
/usr/bin/echo -e "\$ lvcreate -n swap -l CURRENT_LE_for_swap VG1"
/usr/bin/echo -e "\$ lvcreate -n home -l CURRENT_LE_for_home VG1"
/usr/bin/echo -e "\$ lvchange -a y VG1"
/usr/bin/echo -e "\$ mkfs.xfs -f /dev/mapper/VG1-root -L root -m uuid=xxx"
/usr/bin/echo -e "\$ mkswap /dev/mapper/VG1-swap -L swap -U uuid"
/usr/bin/echo -e "\$ mkfs.xfs -f /dev/mapper/VG1-home -L /home -m uuid=xxx"


/usr/bin/echo -e "\n\n-Restore /, /boot and /boot/efi partition: --------"
/usr/bin/echo -e "See commands in backing up section."

/usr/bin/echo -e "\n.Restore /boot partition:"
/usr/bin/echo -e "\$ fsarchiver restfs dev_sda1.boot.fsa id=0,dest=/dev/sd?? -A  <==restore partition"

/usr/bin/echo -e "\n.Restore / partition:"
/usr/bin/echo -e "\$ fsarchiver restfs dev_mapper_VG1-root.root.fsa id=0,dest=/dev/mapper/VG1-root -A  <==restore partition"

/usr/bin/echo -e "\$ reboot with Rocky Linux installation usb"
/usr/bin/echo -e "  and run the below commands to install bootloader and to fix MBR/grub:"

/usr/bin/echo -e "\n\n-Install GRUB2 bootloader -------------------"
/usr/bin/echo -e " .If your system can't boot up, you need to fix the GRUB and MBR."
/usr/bin/echo -e " .The 'grub2_install /dev/sda' will install GRUB2 bootloader to /dev/sda."
/usr/bin/echo -e "  and create /boot/grub2 dir for you."
/usr/bin/echo -e "   -Restart the system and boot using CentOS 8 / Rocky Linux 9 installation ISO/DVD."
/usr/bin/echo -e "   -At the CentOS 8 / Rocky Linux 9 installation menu, select Troubleshooting and press <ENTER>."
/usr/bin/echo -e "   -Select Rescue ... a CentOS (Rocky Linux) Linux system and press <ENTER>."
/usr/bin/echo -e "   -It will ask if you want to mount your filesystem, choose '1' to continue."
/usr/bin/echo -e "    (It will mount your / Linux under /mnt/sysimage.)"
/usr/bin/echo -e "   -Press <ENTER> again to acquire a shell."
/usr/bin/echo -e "# chroot /mnt/sysimage"
/usr/bin/echo -e "# grub2-install /dev/sda    <-Note: choose the correct boot disk device"
/usr/bin/echo -e "# reboot"

/usr/bin/echo -e "\n-Fixing lvm system devices (/etc/lvm/devices/system.devices) ---------------"
/usr/bin/echo -e " .Because newly creation of lvm doesn't match the lvm of the restored system"
/usr/bin/echo -e "  thus the pvs, vgs, lvms commands not working with error:"
/usr/bin/echo -e "  \"Devices file sys_wwid naa.50014ee0ac8d2073 PVID 15NVJxhAe3j9JXboEkIE3R2eCPwYE0N7 last seen on /dev/sda2 not found.\""
/usr/bin/echo -e "  you need to update the new lvm to the system:"
/usr/bin/echo -e "# lvmdevices --deldev /dev/dev/sda2  |" 
/usr/bin/echo -e "# lvmdevices --adddev /dev/dev/sda2  | <-It will change /etc/lvm/devices/system.devices"
/usr/bin/echo -e "# lvchange -a y VG1                    <-Activate VG1"


/usr/bin/echo -e "\n\n-Note: -----------------------"
/usr/bin/echo -e " .All partitons' UUID must be set the same as the ones on the old disk."
/usr/bin/echo -e " ."


/usr/bin/echo -e "\n\nCreated on $DATE - Hiep\n"




#============================================================
# <attach target for cloning, say, /dev/sdc>
# CURRENT_LE=2000  (get exact "Current LE" value from lvdisplay)
# NEW_SIZE="20G"
# parted -a optimal /dev/sdc mklabel gpt mkpart p1 ext4 0% 100%
# pvcreate /dev/sdc1
# vgcreate nodexx /dev/sdc1
# lvcreate -n lv_root -l $CURRENT_LE nodexx
# dd if=/dev/node07/lv_root of=/dev/nodexx/lv_root bs=4M
# lvresize /dev/vg_nodexx/lv_root -L $NEW_SIZE
# fsck.ext4 -f -y /dev/vg_nodexx/lv_root
# resize2fs /dev/vg_nodexx/lv_root


