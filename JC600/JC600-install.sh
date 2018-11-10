#/bin/bash
echo -e "\nArch Linux ARM to SD Card"
echo -e "* JC600"

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

echo -e "\nAll drives on this computer:\n"
ls -1 /dev/sd?

echo -e "\nChoose disk (like /dev/DEV):\n"
read DEV

SDCARD=/dev/$DEV

echo -e "\n\nCurrent partitioning of $SDCARD:\n"
parted $SDCARD print

echo -e "\nYou chose $SDCARD \nAre you sure to continue? Press Ctrl-C to abort\!"
read

parted -s $SDCARD unit s print
parted -s $SDCARD mktable msdos
parted -s $SDCARD mkpart primary fat32 8192s 512MiB
parted -s $SDCARD mkpart primary ext4 1048576s 59GiB
parted -s $SDCARD mkpart primary ext4 123731968s 109GiB
parted -s $SDCARD mkpart primary ext4 228589568s 100%
parted -s $SDCARD unit s print

echo -e ".. format and mount boot partition"
mkfs.ext4 "$SDCARD"2
mount "$SDCARD"2 /mnt

echo -e ".. foramt and mount home partition"
mkfs.ext4 "$SDCARD"3
mkdir -p mkdir /mnt/home
mount "$SDCARD"3 /mnt/home

echo -e ".. format and mount boot partition"
mkfs.vfat "$SDCARD"1
mkdir /mnt/boot
mount "$SDCARD"1 /mnt/boot

echo -e ".. format and mount boot partition"
mkfs.ext4 "$SDCARD"4
mkdir /mnt/mnt/data -p
mount "$SDCARD"1 /mnt/mnt/data

echo -e ".. creating swap partition"
fallocate -l 16G /mnt/swapfile
chmod 0600 /mnt/swapfile
mkswap /mnt/swapfile
swapon /mnt/swapfile

echo -e "\nUpdate pacman and install base and base-devel"
pacman -Syy --noconfirm
pacman -S archlinux-keyring --noconfirm
pacman-key --refresh

echo -e "\n.. installing system"
pacstrap /mnt base base-devel openssh sudo ntp wget screen

echo -e "\n.. creating fstab"
genfstab -U -p /mnt >> /mnt/etc/fstab
sed -i "s|/mnt/swapfile|/swapfile|" /mnt/etc/fstab

## Tuning
echo -e "\n.. generic tuning"
wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/config/generic_config.sh
chmod +x generic_config.sh
cp generic_config.sh /mnt/
echo '\n... Enter a default password for root and megavolts users:'
stty -echo
read DRIVE_PASSPHRASE
stty echo
arch-chroot /mnt ./generic_config.sh $DRIVE_PASSPHRASE

## JC600 video driver, bootloader, boot and kernel image
echo -e ""
echo -e ".. Specific JC600 tuning"
wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/JC600/JC600-config.sh -O /mnt/JC600-config.sh
chmod +x /mnt/JC600-config.sh
arch-chroot /mnt ./JC600-config.sh $SDCARD

## JC600 video driver, bootloader, boot and kernel image
echo -e "\n.. minimal graphical router with PMP"
wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/JC600/JC600-graphical_PMP.sh
chmod +x specific_config.sh
cp specific_config.sh /mnt/
arch-chroot /mnt ./specific_config.sh $SDCARD

rm /mnt/{JC600-config, generic_config.sh, JC600-graphical_PMP.sh}
umount /mnt{/boot,/home,/}
