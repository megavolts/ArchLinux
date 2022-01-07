# /bin/bash
# Dual boot with windows
#
#  1            2048         1050623   512.0 MiB   EF00  EFI system partition
#  2         1050624         1083391    16.0 MiB         Microsoft Reserved
#  3         1083392       314402815   149.4 GiB         Microsoft Windows
#  4       314402816       315654143   611.0 MiB         Windows recovery environment
#  5       315654144      3907029134     1.7 TiB   8300  Linux filesystem on LVM

DISK=/dev/nvme0n1
BOOTPART=1
CRYPTPART=5
sgdisk -n $ROOTPART:315654144:3907029134 -t $ROOTPART:8300 -c $ROOTPART:"CRYPTARCH" $DISK

echo 'Enter a default passphrase use to encrypt the disk and serve as password for root and megavolts:'
stty -echo
read PWD
stty echo

# echo -e ".. prepare boot partition"
# mkfs.fat -F32 ${DISK}${BOOTPART}

echo -e ".. wipe partition"
# Wipe partition with zeros after creating an encrypted container with a random key
cryptsetup open --type plain ${DISK}p$BOOTPART container --key-file /dev/urandom 
dd if=/dev/zero of=/dev/mapper/container status=progress bs=1M
cryptsetup close container

echo -e ".. encrypting root partition"
echo -en $PWD | cryptsetup luksFormat --align-payload=8192 -s 512 -c aes-xts-plain64 /dev/disk/by-partlabel/CRYPTARCH -q
echo -en $PWD | cryptsetup luksOpen /dev/disk/by-partlabel/CRYPTARCH cryptarch
mkfs.btrfs --force --label arch /dev/mapper/cryptarch

echo -e ".. create subvolumes"
mount -o defaults,compress=lzo,noatime,nodev,ssd,discard /dev/mapper/cryptarch /mnt/
mkdir -p /mnt/

btrfs subvolume create /mnt/@root
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@swap
btrfs subvolume create /mnt/@data
umount /mnt

# Mount subvolume
mount -o defaults,compress=lzo,noatime,nodev,ssd,discard,subvol=@root /dev/mapper/cryptarch /mnt
mkdir -p /mnt/home
mount -o defaults,compress=lzo,noatime,nodev,ssd,discard,subvol=@home /dev/mapper/cryptarch /mnt/home
mkdir -p /mnt/mnt/data
mount -o defaults,compress=lzo,noatime,nodev,ssd,discard,subvol=@data /dev/mapper/cryptarch /mnt/mnt/data

# Create swapfile
mkdir -p /mnt/swap
mount -o defaults,compress=lzo,noatime,nodev,ssd,discard,subvol=@swap /dev/mapper/cryptarch /mnt/swap

truncate -s 0 /mnt/swap/swapfile
chattr +C /mnt/swap/swapfile
btrfs property set /mnt/swap/swapfile compression none
fallocate -l 16G /mnt/swap/swapfile
chmod 600 /mnt/swap/swapfile
mkswap /mnt/swap/swapfile -L swap
swapon /mnt/swap/swapfile

##
echo -e "prepare disk for installation"
#mkfs.vfat -F32 ${DISK}$BOOTPART
mkdir /mnt/boot
mount ${DISK}p$BOOTPART /mnt/boot

# Install Arch Linux
pacman -Sy
#pacstrap  /mnt $(pacman -Sqg base | sed 's/^linux$/&-zen/') base-devel openssh sudo ntp wget grml-zsh-config btrfs-progs networkmanager linux-firmware sof-firmware yajl linux-zen mkinitcpio
pacstrap  /mnt base linux-zen linux-zen-headers base-devel openssh sudo ntp wget grml-zsh-config btrfs-progs networkmanager linux-firmware sof-firmware yajl mkinitcpio git

echo -e "Create fstab"
genfstab -L -p /mnt >> /mnt/etc/fstab
mkdir -p /mnt/mnt/btrfs-arch
echo "# arch root btrfs volume" >> /mnt/etc/fstab
echo "LABEL=arch  /mnt/btrfs-arch btrfs rw,nodev,noatime,ssd,discard,compress=lzo,space_cache,noauto 0 0" >> /mnt/etc/fstab
sed 's/\/mnt\/swap/\/swap/g' /mnt/etc/fstab

# ## Tuning
# echo -e ""
# echo -e ".. generic tuning"
# wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/config/generic_config-V2.sh
# chmod +x generic_config-V2.sh
# cp generic_config-V2.sh /mnt/ 
# arch-chroot /mnt ./generic_config-V2.sh $PWD $USER kanaga
# rm /mnt/generic_config-V2.sh

# ## Specific tuning
# echo -e ""
# echo -e ".. Specific X220 tuning"
# wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/X220/source/specific_config.sh
# chmod +x specific_config.sh
# cp specific_config.sh /mnt/
# arch-chroot /mnt ./specific_config.sh $TANK_DEV_PART $FORMAT_TANK
# rm /mnt/specific_config.sh
    
# ## Install software packages
# echo -e ""
# echo -e ".. Install software packages"
# wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/source/software_install.sh
# chmod +x software_install.sh
# cp specific_config.sh /mnt/
# arch-chroot /mnt ./specific_config.sh $root_dev $home_dev

# # rm /mnt/{software_install.sh, specific_config.sh, generic_config.sh}
# # umount /mnt{/boot,/home,/}
