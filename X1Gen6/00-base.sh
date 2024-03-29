
# /bin/bash
# 10/30/2023
# Dual boot with windows
# With 1 DISK, 4TB
# /dev/nvme0n1p1  512.0MiB  EF00  EFI system partition
# /dev/nvme1n1p1    8300 Linux Filesystem on LVM
# /dev/nvme1n1p2 1.5TiB
#   1            2048         1050623   512.0 MiB   EF00  EFI system partition
#   2         1050624         1083391   16.0 MiB    0C01  Microsoft reserved ...
#   3         1083392       537954303   256.0 GiB   0700  Basic data partition
#   4       537954304       571508735   16.0 GiB    2700  Recovery
# IF NTFSDATA
#   5       571508736      5666551807   2.4 TiB     8300  cryptarch
#   6      5666551808      7814035455   1024.0 GiB  0700  ntfsdata
# ELSE 
#   6      571508736       7814035455   3.4 TiB     8300  cryptarch
# btrfs with flat layout: /, /var/

DISK=/dev/nvme0n1
NEWUSER=megavolts
BOOTPART=1
CRYPTPART=5
NEWINSTALL=false
INSTALL=True
NTFSDATA=True
WIPEDISK=false
TZDATA=America/Anchorage
echo 'Enter a default passphrase use to encrypt the disk and serve as password for root and megavolts:'
stty -echo
read PASSWORD
stty echo


echo -e "DISKS PREPARATION"
if $NEWINSTALL
then
  echo ".. New installation, create new partition table"
  sgdisk -n $ROOTPART:315654144:3907029134 -t $ROOTPART:8300 -c $ROOTPART:"CRYPTARCH" $DISK

  # echo -e ".. prepare boot partition"
  # mkfs.fat -F32 ${DISK}${BOOTPART}
  WIPEDISK=true
else
  echo -e "... Decrypt root device"
  echo -en $PASSWORD | cryptsetup luksOpen /dev/disk/by-partlabel/CRYPTARCH arch
fi

if $WIPEDISK
  echo -e ".. wipe partition"
  # Wipe partition with zeros after creating an encrypted container with a random key
  cryptsetup open --type plain ${DISK}p$BOOTPART container --key-file /dev/urandom 
  dd if=/dev/zero of=/dev/mapper/arch status=progress bs=1M
  echo -e ".. encrypting root partition"
  echo -en $PASSWORD | cryptsetup luksFormat --align-payload=4096 /dev/disk/by-partlabel/cryptarch -q
  echo -en $PASSWORD | cryptsetup luksOpen /dev/disk/by-partlabel/cryptarch arch
  mkfs.btrfs --force --label arch /dev/mapper/arch
fi

echo -e ".. create subvolumes"
mount -o defaults,compress=zstd:3,noatime,nodev,ssd,discard /dev/mapper/root /mnt/

# if $INSTALL or $WIPEDISK
# then
#   echo -e "... create new root, var and tmp subvolume"
#   btrfs subvolume create /mnt/@root
#   btrfs subvolume create /mnt/@home
#   btrfs subvolume create /mnt/@data
# else

if $WIPEROOT; then
  # preserve home and data subvolume, delete other
  btrfs subvolume delete /mnt/{@beesroot,@beesdata,@tmp,@var_log,@var_tmp,@var_abs,@var_cache_pacman_pkg,@snapshot,@swap}
  # move old root subvolume
fi
  
echo -e "... Create new root, var and tmp subvolume"
btrfs subvolume create /mnt/@root
# arch wiki recommentd
btrfs subvolume create /mnt/@var_log
# to prevent slowdown
btrfs subvolume create /mnt/@tmp
btrfs subvolume create /mnt/@var_abs
btrfs subvolume create /mnt/@var_tmp
btrfs subvolume create /mnt/@var_cache_pacman_pkg

if $WIPEROOT; then
  echo -e "... Backup old root to @root.old"
  mv /mnt/@root /mnt/@root.old

  echo -e "... Create new root @root"
  btrfs subvolume create /mnt/@root

  echo -e "... Create root snapshots"
  if [ ! -d /mnt/@snapshots/ ]; then
    btrfs subvolume create /mnt/@snapshots
  fi
  if [ ! -d /mnt/data/@snapshots/@root_snaps ]; then
    btrfs subvolume create /mnt/@snapshots/@root_snaps
  fi
fi

if $WIPEHOME; then
  echo -e "... Backup old home to @home.old"
  mv /mnt/@home /mnt/@home.old

  echo -e "... Create new home and home snapshots subvolume"
  btrfs subvolume create /mnt/@home
  if [ ! -d /mnt/@snapshots/ ]; then
    btrfs subvolume create /mnt/@snapshots
  fi
  if [ ! -d /mnt/data/@snapshots/@home_snaps ]; then
    btrfs subvolume delete /mnt/@snapshots/@home_snaps/*/snapshot
    rm -R /mnt/@snapshots/@home_snaps/*
    btrfs subvolume delete /mnt/@snapshots/@home_snaps
    btrfs subvolume create /mnt/@snapshots/@home_snaps
  else
    btrfs subvolume create /mnt/@snapshots/@home_snaps
  fi
fi


# Mount root btrfs root volume
mkdir -p /mnt/mnt/btrfs/arch
mount -o defaults,compress=zstd:3,noatime,nodev,ssd,discard,space_cache=v2 /dev/mapper/arch /mnt/mnt/btrfs/arch


# Create mountpoints and mount root subvolumes
echo -e ".. create root subvolume mountpoints"
mkdir -p /mnt/{boot,.boot,tmp,var/log,var/tmp,var/abs,var/cache/pacman/pkg,home,mnt/data}
echo -e ".. mount subvolume for install"
mount -o defaults,compress=zstd:3,noatime,nodev,ssd,discard,space_cache=v2,subvol=@root /dev/mapper/arch /mnt
mount -o defaults,compress=zstd:3,noatime,nodev,nodatacow,ssd,discard,subvol=@tmp /dev/mapper/arch /mnt/tmp
mount -o defaults,compress=zstd:3,noatime,nodev,nodatacow,ssd,discard,subvol=@var_log /dev/mapper/arch /mnt/var/log
mount -o defaults,compress=zstd:3,noatime,nodev,nodatacow,ssd,discard,subvol=@var_tmp /dev/mapper/arch /mnt/var/tmp
mount -o defaults,compress=zstd:3,noatime,nodev,nodatacow,ssd,discard,subvol=@var_abs /dev/mapper/arch /mnt/var/abs
mount -o defaults,compress=zstd:3,noatime,nodev,nodatacow,ssd,discard,subvol=@var_cache_pacman_pkg /dev/mapper/arch /mnt/var/cache/pacman/pkg
mount -o defaults,compress=zstd:3,noatime,nodev,ssd,discard,space_cache=v2,subvol=@home /dev/mapper/arch /mnt/home
mount -o defaults,compress=zstd:3,noatime,nodev,ssd,discard,space_cache=v2,subvol=@data /dev/mapper/arch /mnt/mnt/data

echo -e ".. create and activate swapfile"
# Create swapfile if not existing
btrfs subvolume create /mnt/mnt/btrfs/arch/@swap
btrfs filesystem mkswapfile --size=64G /mnt/mnt/btrfs/arch/@swap/swapfile
swapon /mnt/mnt/btrfs/arch/@swap/swapfile
RESUME_OFFSET=$(btrfs inspect-internal map-swapfile -r /mnt/mnt/btrfs/arch/@swap/swapfile)

# BTRFS data subvolume
echo -e ".. create media subvolume on data and mount"
if [ ! -e /mnt/btrfs/data/@media ]; then
  btrfs subvolume create /mnt/mnt/btrfs/arch/@media
fi
if [ -e /mnt/btrfs/data/@UAF-data ]; then
  btrfs subvolume create /mnt/mnt/btrfs/arch/@UAF-data
fi
mkdir -p /mnt/mnt/data/{media,UAF-data}
mkdir -p /mnt/mnt/data/media/{photography,wallpaper,meme,graphisme,tvseries,movies,videos,musics}
mount -o defaults,nodev,noatime,compress=zstd:3,ssd,discard,space_cache=v2,subvol=@media /dev/mapper/arch /mnt/mnt/data/media
mount -o defaults,nodev,noatime,compress=zstd:3,ssd,discard,space_cache=v2,subvol=@UAF-data /dev/mapper/arch /mnt/mnt/data/UAF-data
mount /dev/nvme0n1p6 /mnt/mnt/data/media/photography

# boot partition EFI and EFI_LINUX
echo -e ".. mount linux disk boot partition to /mnt/boot"
mount ${DISK}p${BOOTPART} /mnt/boot

echo -e "Arch Linux Installation"
echo -e ".. Install base packages"
pacman -Sy
pacman -S --noconfirm archlinux-keyring
pacstrap /mnt base linux-zen linux-zen-headers base-devel openssh sudo ntp wget grml-zsh-config btrfs-progs networkmanager usbutils linux-firmware sof-firmware yajl mkinitcpio git go nano zsh terminus-font refind intel-ucode rsync

echo -e ".. install basic console tools"
pacstrap /mnt mlocate acl util-linux fwupd arp-scan htop lsof strace screen refind terminus-font sudo zsh ntfs-3g

echo -e ".. Create fstab"
genfstab -L -p /mnt >> /mnt/etc/fstab
sed 's/\/mnt\/swap/\/swap/g' /mnt/etc/fstab


echo -e "... Add tmpfs to fstab"
echo "tmpfs   /tmp    tmpfs  rw,nr_inodes=5k,noexec,nodev,nosuid,uid=user,gid=group,mode=1700 0 0" >> /mnt/etc/fstab

echo -e " .. Allow wheel group to sudo"
sed -i 's/# %wheel ALL=(ALL:ALL)/%wheel ALL=(ALL:ALL)/g' /mnt/etc/sudoers

echo -e "Configure system"
# set timezone
echo -e ".. > set timezone to America/Anchorage"
ln -sf /usr/share/zoneinfo/${TZDATA} /mnt/etc/localtime
arch-chroot /mnt hwclock --systohc
echo ${TZDATA} >> /mnt/etc/timezone

# generate locales for en_US
echo -e ".. > set locale to en_US"
sed -e 's/#en_US/en_US/g' -i /mnt/etc/locale.gen
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
arch-chroot /mnt locale-gen

# set keyboard
echo -e ".. > set keyboard"
echo "FONT=ter-132n" >> /mnt/etc/vconsole.conf

# set hostname
echo -e ".. Set hostname & network manager"
echo $HOSTNAME > /mnt/etc/hostname
echo "127.0.1.1 localhost $HOSTNAME.localdomain    $HOSTNAME" >> /mnt/etc/hosts
echo "::1 localhost $HOSTNAME" >> /mnt/etc/hosts

arch-chroot /mnt /bin/zsh