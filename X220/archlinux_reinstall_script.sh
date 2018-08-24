#/bin/bash
# Reinstall
#
echo -e "prepare disk for installation"
echo 'Enter a default passphrase use to encrypt the disk and serve as password for root and megavolts:'

stty -echo
read DRIVE_PASSPHRASE
stty echo

echo -e ".. encrypting root partition"
echo -en $DRIVE_PASSPHRASE | cryptsetup -c aes-xts-plain64 -s 512 -h sha512 -i 5000 --use-random -q luksFormat /dev/sdb4
echo -en $DRIVE_PASSPHRASE | cryptsetup luksOpen /dev/sdb4 cryptroot
mkfs.ext4 /dev/mapper/cryptroot
mount /dev/mapper/cryptroot /mnt

echo -e ".. create encryptation file for home partition"
dd if=/dev/urandom of=/mnt/home.keyfile bs=512 count=4
echo -en $DRIVE_PASSPHRASE | cryptsetup luksAddKey /dev/sdb5 /mnt/home.keyfile
echo -e ".. mounting home partition"
echo -en $DRIVE_PASSPHRASE | cryptsetup luksOpen /dev/sdb5 crypthome
mkdir -p mkdir /mnt/home
mount /dev/mapper/crypthome /mnt/home

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

echo -e ""
echo -e "Tuning X220 adak"
wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/X220/source/config_archlinux.sh
chmod +x config_archlinux.sh
cp config_archlinux.sh /mnt/
arch-chroot /mnt ./config_archlinux.sh $DRIVE_PASSWORD
umount /mnt{/boot,/home,/}

#pressanykey() {
#  echo -e "# press a key to continue"
#  read -n1 -p "$txtpressanykey"
#}

