# /bin/bash
# Reinstall
#
#  1            2048         1067007   512.0 MiB   EF00  EFI system partition
#  5       261599232       523743231   466.0 GiB   8300  Linux filesystem on LVM

DISK=/dev/sdb
BOOTPART=1
ROOTPART=2

sgdisk -n $BOOTPART:0:0 -t $BOOTPART:EF00 -c $BOOTPART:"BOOT" $DISK
sgdisk -n $ROOTPART:0:0 -t $ROOTPART:8300 -c $ROOTPART:"CRYPTARCH" $DISK

echo 'Enter a default passphrase use to encrypt the disk and serve as password for root and megavolts:'
stty -echo
read PWD
stty echo

echo -e ".. prepare boot partition"
mkfs.fat -F32 ${DISK}${BOOTPART}

echo -e ".. wipe partition"
# Wipe partition with zeros after creating an encrypted container with a random key
cryptsetup open --type plain ${DISK}$BOOTPART container --key-file /dev/urandom 
dd if=/dev/zero of=/dev/mapper/container status=progress bs
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

umount /mnt
# Mount subvolume
mount -o defaults,compress=lzo,noatime,nodev,ssd,discard,subvol=@root /dev/mapper/cryptarch /mnt
mkdir -p /mnt/home
mount -o defaults,compress=lzo,noatime,nodev,ssd,discard,subvol=@home /dev/mapper/cryptarch /mnt/home

# Create swapfile
truncate -s 0 /mnt/swapfile
chattr +C /mnt/swapfile
btrfs property set /mnt//swapfile compression none
fallocate -l 16G /mnt/swapfile
chmod 600 /mnt/swapfile
mkswap /mnt/swapfile -L swap
swapon /mnt/swapfile

##
echo -e "prepare disk for installation"
mkfs.vfat -F32 ${DISK}$BOOTPART
mkdir /mnt/boot
mount ${DISK}$BOOTPART /mnt/boot

# Install Arch Linux
pacman -Sy
pacstrap  /mnt $(pacman -Sqg base | sed 's/^linux$/&-zen/') base-devel openssh sudo ntp wget grml-zsh-config refind-efi btrfs-progs networkmanager

echo -e "Create fstab"
genfstab -L -p /mnt >> /mnt/etc/fstab
mkdir -p /mnt/mnt/btrfs-arch
echo "# arch root btrfs volume" >> /mnt/etc/fstab
echo "LABEL=arch  /mnt/btrfs-arch btrfs rw,nodev,noatime,ssd,discard,compress=lzo,space_cache,noauto 0 0" >> /mnt/etc/fstab
sed 's/\/mnt\/swapfile/\/swapfile/g' /mnt/etc/fstab

## Tuning
echo -e "\n"
echo -e ".. generic tuning"

## Tuning
echo -e ""
echo -e ".. generic tuning"
wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/config/generic_config-V2.sh
chmod +x generic_config-V2.sh
cp generic_config-V2.sh /mnt/ 
arch-chroot /mnt ./generic_config-V2.sh $PWD $USER adak
rm /mnt/generic_config-V2.sh

## Specific tuning
echo -e ""
echo -e ".. Specific X220 tuning"
wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/X220/source/specific_config.sh
chmod +x specific_config.sh
cp specific_config.sh /mnt/
arch-chroot /mnt ./specific_config.sh 
rm /mnt/specific_config.sh


    
# ## Install software packages
# echo -e ""
# echo -e ".. Install software packages"
# wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/source/software_install.sh
# chmod +x software_install.sh
# cp specific_config.sh /mnt/
# arch-chroot /mnt ./specific_config.sh $root_dev $home_dev

# rm /mnt/{software_install.sh, specific_config.sh, generic_config.sh}
# umount /mnt{/boot,/home,/}
