#/bin/bash
# Reinstall
#

#
#  1            2048         1067007   512.0 MiB   EF00  EFI system partition
#  2         1067008         1099775   16.0 MiB    0C01  Microsoft reserved ...
#  3         1099776       261598247   124.2 GiB   0700  Basic data partition
#  5       261599232       523743231   125.0 GiB   8300  Linux filesystem on LVM

DISK=/dev/sdb
PART=2

sgdisk -n $PART:0:0 -t $PART:8300 -c $PART:"CRYPTARCH" $DISK

echo 'Enter a default passphrase use to encrypt the disk and serve as password for root and megavolts:'
stty -echo
read PWD
stty echo

echo -e ".. prepare boot partition"
mkfs.fat -F32 /dev/sdb1

echo -e ".. wipe partition
# Wipe partition with zeros after creating an encrypted container with a random key
cryptsetup open --type plain ${DISK}$PART container --key-file /dev/urandom 
dd if=/dev/zero of=/dev/mapper/container status=progress bs
cryptsetup close container

echo -e ".. encrypting root partition"
cryptsetup luksFormat --align-payload=8192 -s 512 -c aes-xts-plain64 /dev/disk/by-partlabel/CRYPTARCH
echo -en $PWD | cryptsetup luksOpen /dev/disk/by-partlabel/CRYPTARCH cryptarch
mkfs.btrfs --force --label arch /dev/mapper/cryptarch



echo -e ".. create subvolumes"
mount -o defaults,compress=lzo,noatime,nodev,ssd,discard /dev/mapper/cryptarch /mnt/
mkdir -p /mnt/_snapshot
mkdir -p /mnt/_active

btrfs subvolume create /mnt/@active/@root
btrfs subvolume create /mnt/@active/@home

umount /mnt
# Mount subvolume
mount -o defaults,compress=lzo,noatime,nodev,ssd,discard,subvol=@active/@root /dev/mapper/cryptarch /mnt
mkdir -p /mnt/home
mount -o defaults,compress=lzo,noatime,nodev,ssd,discard,subvol=@active/@home /dev/mapper/cryptarch /mnt/home
mkdir -p /mnt/swap
mount ${DISK}1 /mnt/boot

# Create swapfile
truncate -s 0 /mnt/swapfile
chattr +C /mnt/swapfile
btrfs property set /mnt//swapfile compression none
fallocate -l 16G /mnt/swapfile
chmod 600 /mnt/swapfile
mkswap /mnt/swapfile -L swap
swapon /mnt/swapile

##
echo -e "prepare disk for installation"
mkfs.vfat -F32 /dev/sdb1
mkidr /mn/boot
mount /dev/sdb1 /mnt/boot



# Install Arch Linux
pacstrap $(pacman -Sqg base | sed 's/^linux$/&-zen/') /mnt  base-devel openssh sudo ntp wget grml-zsh-config refind-efi btrfs-progs networkmanager




echo -e ""
echo -e "Create fstab"
genfstab -L -p /mnt >> /mnt/etc/fstab
mkdir -p /mnt/mnt/btrfs-arch
echo "# arch root btrfs volume" >> /mnt/etc/fstab
echo "LABEL=arch  /mnt/btrfs-arch btrfs rw,nodev,noatime,ssd,discard,compress=lzo,space_cache 0 0" >> /mnt/etc/fstab
sed 's/\/mnt\/swapfile/\/swapfile/g' /mnt/etc/fstab

# EXT4 version

echo -e ""
echo -e "Update pacman and install base and base-devel with linux-zen"
pacman -Syy --noconfirm
pacman -S archlinux-keyring --noconfirm
pacman-key --refresh

## Tuning
echo -e ""
echo -e ".. generic tuning"
wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/config/generic_config.sh
chmod +x generic_config.sh
cp generic_config.sh /mnt/
arch-chroot /mnt ./generic_config.sh $DRIVE_PASSWORD
rm /mnt/generic_config.sh



## Specific tuning
echo -e ""
echo -e ".. Specific X220 tuning"
wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/X220/source/specific_config.sh
chmod +x specific_config.sh
cp specific_config.sh /mnt/
arch-chroot /mnt ./specific_config.sh $root_dev $home_dev
rm /mnt/specific_config.sh
    
## Install software packages
echo -e ""
echo -e ".. Install software packages"
wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/source/software_install.sh
chmod +x software_install.sh
cp specific_config.sh /mnt/
arch-chroot /mnt ./specific_config.sh $root_dev $home_dev

rm /mnt/{software_install.sh, specific_config.sh, generic_config.sh}
umount /mnt{/boot,/home,/}
