#/bin/bash
# Reinstall
#

#
#  1            2048         1067007   512.0 MiB   EF00  EFI system partition
#  2         1067008         1099775   16.0 MiB    0C01  Microsoft reserved ...
#  3         1099776       261598247   124.2 GiB   0700  Basic data partition
#  5       261599232       523743231   125.0 GiB   8300  Linux filesystem on LVM

DISK=/dev/sda
PART=4

sgdisk -n $PART:0:0 -t $PART:8300 -c $PART:"CRYPTARCH" $DISK

echo -e "prepare disk for installation"

echo 'Enter a default passphrase use to encrypt the disk and serve as password for root and megavolts:'
stty -echo
read PWD
stty echo

echo -e ".. wipe partition
# Wipe partition with zeros after creating an encrypted container with a random key
cryptsetup open --type plain ${DISK}$PART container --key-file /dev/urandom 
dd if=/dev/zero of=/dev/mapper/container status=progress bs
cryptsetup close container

echo -e ".. encrypting root partition"
cryptsetup luksFormat --align-payload=8192 -s 512 -c aes-xts-plain64 /dev/disk/by-partlabel/CRYPTARCH
echo -en $PWD | cryptsetup luksOpen /dev/disk/by-partlabel/CRYPTARCH arch
mkfs.btrfs --force --label arch /dev/mapper/arch

echo -e ".. create subvolumes"
echo -e "... create swap 


echo -e ".. mount boot partition"
mkdir /mnt/boot
mount /dev/sdb1 /mnt/boot

echo -e ".. creating swap partition"
fallocate -l 16G /mnt/swapfile
chmod 0600 /mnt/swapfile
mkswap /mnt/swapfile
swapon /mnt/swapfile

echo -e ""
echo -e "Update pacman and install base and base-devel with linux-zen"
pacman -Syy --noconfirm
pacman -S archlinux-keyring --noconfirm
pacman-key --refresh
if [ -f /mnt/boot/vmlinuz-linux-zen ]; then
  rm /mnt/boot/vmlinuz-linux-zen 
  rm /mnt/boot/initramfs-linux-zen.img 
  rm /mnt/boot/initramfs-linux-zen-fallback.img 
fi 

pacstrap $(pacman -Sqg base | sed 's/^\(linux\)$/\1-zen/') /mnt  base-devel openssh sudo ntp wget

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
echo -e ".. Specific X220 tuning"
wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/X220/source/specific_config.sh
chmod +x specific_config.sh
cp specific_config.sh /mnt/
arch-chroot /mnt ./specific_config.sh $root_dev $home_dev

## Install software packages
echo -e ""
echo -e ".. Install software packages"
wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/source/software_install.sh
chmod +x software_install.sh
cp specific_config.sh /mnt/
arch-chroot /mnt ./specific_config.sh $root_dev $home_dev

rm /mnt/{software_install.sh, specific_config.sh, generic_config.sh}
umount /mnt{/boot,/home,/}
