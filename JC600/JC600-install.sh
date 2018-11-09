#/bin/bash
echo -e "\n Arch Linux ARM to SD Card"
echo -e "* JC600"

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

echo -e "\nAll drives on this computer:\n"
ls -1 /dev/sd?

echo -e "\nLast messages in syslog:\n"
dmesg | tail

echo -e "\nChoose disk (like /dev/DEV):\n"
read DEV

SDCARD=/dev/%DEV

echo -e "\n\nCurrent partitioning of $SDCARD:\n"
parted $SDCARD print

echo -e "\n\nYou chose $SDCARD\nAre you sure to continue? Press Ctrl-C to abort!"
read

parted -s $SDCARD unit s print
parted -s $SDCARD mktable msdos
parted -s $SDCARD mkpart primary fat32 8192s 512MiB
parted -s $SDCARD mkpart primary ext4 1048576s 59GiB
parted -s $SDCARD mkpart primary ext4 123731968s 109GiB
parted -s $SDCARD mkpart primary ext4 228589568s 100%
parted -s $SDCARD unit s print

echo -e "prepare disk for installation"
echo 'Enter a default passphrase use to encrypt the disk and serve as password for root and megavolts:'
stty -echo
read DRIVE_PASSPHRASE
stty echo

echo -e ".. encrypting root partition"
echo -en $DRIVE_PASSPHRASE | cryptsetup -c aes-xts-plain64 -s 512 -h sha512 -i 5000 --use-random -q luksFormat "$SDCARD"2
echo -en $DRIVE_PASSPHRASE | cryptsetup luksOpen "$SDCARD"2 cryptroot
mkfs.ext4 /dev/mapper/cryptroot
mount /dev/mapper/cryptroot /mnt

echo -e ".. create encryptation file for home partition"
dd if=/dev/urandom of=/mnt/home.keyfile bs=512 count=4
echo -en $DRIVE_PASSPHRASE | cryptsetup -c aes-xts-plain64 -s 512 -h sha512 -i 5000 --use-random -q luksFormat "$SDCARD"3
echo -en $DRIVE_PASSPHRASE | cryptsetup luksAddKey "$SDCARD"3 /mnt/home.keyfile
echo -e ".. mounting home partition"
echo -en $DRIVE_PASSPHRASE | cryptsetup luksOpen "$SDCARD"3 crypthome
mkfs.ext4 /dev/mapper/crypthome
mkdir -p mkdir /mnt/home
mount /dev/mapper/crypthome /mnt/home

echo -e ".. mount boot partition"
mkfs.vfat "$SDCARD"1
mkdir /mnt/boot
mount "$SDCARD"1 /mnt/boot

echo -e ".. creating swap partition"
fallocate -l 16G /mnt/swapfile
chmod 0600 /mnt/swapfile
mkswap /mnt/swapfile
swapon /mnt/swapfile

echo -e "\nUpdate pacman and install base and base-devel with linux-zen"
pacman -Syy --noconfirm
pacman -S archlinux-keyring --noconfirm
pacman-key --refresh
if [ -f /mnt/boot/vmlinuz-linux-zen ]; then
  rm /mnt/boot/vmlinuz-linux-zen 
  rm /mnt/boot/initramfs-linux-zen.img 
  rm /mnt/boot/initramfs-linux-zen-fallback.img 
fi 

pacstrap /mnt base base-devel openssh sudo ntp wget screen linux-zen

echo -e ""
echo -e "Create fstab"
genfstab -U -p /mnt >> /mnt/etc/fstab
sed -i "s|/mnt/swapfile|/swapfile|" /mnt/etc/fstab

## Tuning
echo -e ""
echo -e ".. generic tuning"
wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/config/generic_config.sh
chmod +x generic_config.sh
cp generic_config.sh /mnt/
arch-chroot /mnt ./generic_config.sh $DRIVE_PASSWORD

## Specific tuning
echo -e ""
echo -e ".. Specific JC600 tuning"
wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/JC600/JC600-bootloader.sh
chmod +x specific_config.sh
cp specific_config.sh /mnt/
arch-chroot /mnt ./specific_config.sh "$SDCARD"2 "$SDCARD"3

rm /mnt/{specific_config.sh, bootloader.sh}
umount /mnt{/boot,/home,/}
