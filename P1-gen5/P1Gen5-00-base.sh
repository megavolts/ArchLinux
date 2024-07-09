# /bin/bash
# Dual boot with windows
# With 2 DISK
# Linux/Data Disk: /dev/nvme1n1
#  1            2048         1050623   512.0 MiB   EF00  EFI2
#  2         1050624       537921535   256.0 GiB   8300  CRYPTROOT
#  3       537921536      7814035455     3.4 TiB   8300  CRYPTDATA
# Windows Disk: /dev/nvme0n1

HOSTNAME=atka
TZ=America/Anchorage
NEWUSER=megavolts

WINDISK=/dev/nvme0n1
WINBOOTPART=1

DISK=/dev/nvme1n1
BOOTPART=1
ROOTPART=2
DATAPART=3

NEWINSTALL=False
NTFSDATA=False

NEWROOT=True
WIPEROOT=False # False: preserve a copy of old root under @root_old
WIPESNAP=True 
WIPEDATA=False

echo -e "DISKS PREPARATION"
if $NEWINSTALL
then
  echo ".. New installation, create new partition table"
  sgdisk -n $ROOTPART:1050624:537921535 -t $ROOTPART:8300 -c $ROOTPART:"CRYPTROOT" $DISK

  # echo -e ".. prepare boot partition"
  mkfs.fat -F32 ${DISK}${BOOTPART} -n EFI2

  echo -e "... Wipe root partition"
  # Wipe partition with zeros after creating an encrypted container with a random key
  cryptsetup open --type plain ${DISK}p$BOOTPART container --key-file /dev/urandom 
  dd if =/dev/zero of=/dev/mapper/container status=progress bs=1M
  cryptsetup close container
  echo -e "... Encrypt root device"
  echo -en $PASSWORD | cryptsetup luksFormat ${DISK}p${ROOTPART} -q
  echo -e "... Decrypt root device"
  echo -en $PASSWORD | cryptsetup luksOpen /dev/disk/by-partlabel/CRYPTROOT root
  mkfs.btrfs --force --label arch /dev/mapper/root
else
  echo -e "... Decrypt root device"
  echo -en $PASSWORD | cryptsetup luksOpen ${DISK}p${ROOTPART} root
fi

if $WIPEDATA
  echo -e "... Encrypt data partition"
  echo -en $PASSWORD | cryptsetup luksFormat ${DISK}p${DATAPART} -q
  echo -e "... Decrypt data partition"
  echo -en $PASSWORD | cryptsetup luksOpen /dev/disk/by-partlabel/DATAPART data
  mkfs.btrfs --force --label arch /dev/mapper/data
else
  echo -e "... Decrypt data partition"
  echo -en $PASSWORD | cryptsetup luksOpen ${DISK}p${DATAPART} data
fi

echo -e ".. Mount root btrfs subvolume on /mnt"
mount -o defaults,compress=zstd:3,noatime,nodev,ssd,discard /dev/mapper/root /mnt/

if $WIPEROOT; then
  echo $WIPEROOT
  btrfs suvolume delete /mnt/root
else
  mv /mnt/@root /mnt/@root_old
fi

btrfs subvolume delete /mnt/{@beesroot,@beesdata,@tmp,@var_log,@var_tmp,@var_abs,@var_cache_pacman_pkg,@snapshot,@swap}

echo -e "... Create new root, var and tmp subvolume"
btrfs subvolume create /mnt/@root
# arch wiki recommentd
btrfs subvolume create /mnt/@var_log
# to prevent slowdown
btrfs subvolume create /mnt/@tmp
btrfs subvolume create /mnt/@var_abs
btrfs subvolume create /mnt/@var_tmp
btrfs subvolume create /mnt/@var_cache_pacman_pkg

echo -e ".. Mount data btrfs subvolme on /mnt/data"
mkdir -p /mnt/data 
mount -o defaults,compress=zstd:3,noatime,nodev,ssd,discard /dev/mapper/data /mnt/data

if $WIPESNAP; then
  echo -e "... Delete old @root_snaps and recreating it"
  if [ ! -d /mnt/@snapshots/@root_snaps ]; then
    btrfs subvolume create /mnt/@snapshots/@root_snaps
  else
    btrfs subvolume delete /mnt/@snapshots/@root_snaps/*/*
    rm -R /mnt/@snapshot/@root_snaps/*/*
    rm -R /mnt/@snapshot/@root_snaps/*
    btrfs subvolume delete /mnt/@snapshots/@root_snaps
  fi
  btrfs subvolume create /mnt/@snapshots/@root_snaps
fi

if $WIPEDATA
  echo -e "... create new home, data and snapshots suvolume"
  btrfs subvolume create /mnt/data/@home
  btrfs subvolume create /mnt/data/@data
  if [ ! -d /mnt/data/@snapshots/ ]; then
    btrfs subvolume create /mnt/data/@snapshots
  fi
  if [ ! -d /mnt/data/@snapshots/@home_snaps ]; then
    btrfs subvolume create /mnt/data/@snapshots/@home_snaps
  fi
fi
umount /mnt{/data,/}

echo -e ".. mount subvolume for install"
# Mount root subvolume
mount -o defaults,compress=zstd:3,noatime,nodev,ssd,discard,space_cache=v2,subvol=@root /dev/mapper/root /mnt

# Mount root and data btrfs root volume
mkdir -p /mnt/mnt/btrfs/{root,data}
mount -o defaults,compress=zstd:3,noatime,nodev,ssd,discard,space_cache=v2 /dev/mapper/root /mnt/mnt/btrfs/root
mount -o defaults,compress=zstd:3,noatime,nodev,ssd,discard,space_cache=v2 /dev/mapper/data /mnt/mnt/btrfs/data

echo -e ".. create and activate swapfile"
# Create swapfile if not existing
btrfs subvolume create /mnt/mnt/btrfs/root/@swapfile
btrfs filesystem mkswapfile --size=72G /mnt/mnt/btrfs/root/@swap/swapfile
swapon /mnt/mnt/btrfs/root/@swap/swapfile
RESUME_OFFSET=$(btrfs inspect-internal map-swapfile -r /mnt/mnt/btrfs/root/@swap/swapfile)

echo -e ".. create root subvolume mountpoints"
mkdir -p /mnt/{boot,.boot,tmp,var/log,var/tmp,var/abs,var/cache/pacman/pkg,home,mnt/data}
mount -o defaults,compress=zstd:3,noatime,nodev,nodatacow,ssd,discard,subvol=@tmp /dev/mapper/root /mnt/tmp
mount -o defaults,compress=zstd:3,noatime,nodev,nodatacow,ssd,discard,subvol=@var_log /dev/mapper/root /mnt/var/log
mount -o defaults,compress=zstd:3,noatime,nodev,nodatacow,ssd,discard,subvol=@var_tmp /dev/mapper/root /mnt/var/tmp
mount -o defaults,compress=zstd:3,noatime,nodev,nodatacow,ssd,discard,subvol=@var_abs /dev/mapper/root /mnt/var/abs
mount -o defaults,compress=zstd:3,noatime,nodev,nodatacow,ssd,discard,subvol=@var_cache_pacman_pkg /dev/mapper/root /mnt/var/cache/pacman/pkg
mount -o defaults,compress=zstd:3,noatime,nodev,ssd,discard,space_cache=v2,subvol=@home /dev/mapper/data /mnt/home
mount -o defaults,compress=zstd:3,noatime,nodev,ssd,discard,space_cache=v2,subvol=@data /dev/mapper/data /mnt/mnt/data

# # BTRFS data subvolume
# echo -e ".. create media subvolume on data and mount"
# if [ !  -e /mnt/btrfs/data/@media ]; then
#   btrfs subvolume create /mnt/mnt/btrfs/data/@media 
# fi
# if [ !  -e /mnt/btrfs/data/@photography ]; then
#   btrfs subvolume create /mnt/mnt/btrfs/data/@photography
# fi
# if [ !  -e /mnt/btrfs/data/@UAF-data ]; then
#   btrfs subvolume create /mnt/mnt/btrfs/data/@UAF-data
# fi
# mkdir -p /mnt/data/{media,UAF-data}
# mkdir -p /mnt/data/media/{photography,wallpaper,meme,graphisme,tvseries,movies,videos,musics}
# mount -o defaults,nodev,noatime,compress=zstd:3,ssd,discard,space_cache=v2,subvol=@media /dev/mapper/data /mnt/data/media
# mount -o defaults,nodev,noatime,compress=zstd:3,ssd,discard,space_cache=v2,subvol=@UAF-data /dev/mapper/data /mnt/data/UAF-data
# mount -o defaults,nodev,noatime,compress=zstd:3,ssd,discard,space_cache=v2,subvol=@photography /dev/mapper/data /mnt/data/media/photography

# boot partition EFI and EFI_LINUX
echo -e ".. mount windows disk boot partition to /mnt/boot"
mount ${WINDISK}p${WINBOOTPART} /mnt/boot
echo -e ".. mount linux disk boot partition to /mnt/.boot"
mount ${DISK}p${BOOTPART} /mnt/.boot

echo -e "Arch Linux Installation"
echo -e ".. Install base packages"
pacman -Sy
pacman -S --noconfirm archlinux-keyring
pacstrap /mnt base linux-zen linux-zen-headers base-devel openssh sudo ntp wget grml-zsh-config btrfs-progs networkmanager usbutils linux-firmware sof-firmware yajl mkinitcpio git go nano zsh terminus-font refind rsync

echo -e ".. install basic console tools"
rm -R /mnt/boot/intel-ucode.img
pacstrap /mnt mlocate acl util-linux fwupd arp-scan htop lsof strace screen refind terminus-font sudo intel-ucode 

echo -e ".. Create fstab"
genfstab -L -p /mnt >> /mnt/etc/fstab
sed 's/\/mnt\/swap/\/swap/g' /mnt/etc/fstab

echo -e "... Add tmpfs to fstab"
echo "tmpfs   /tmp    tmpfs  rw,nr_inodes=5k,noexec,nodev,nosuid,uid=user,gid=group,mode=1700 0 0" >> /mnt/etc/fstab

echo -e " .. Allow wheel group to sudo"
sed -i 's/# %wheel ALL=(ALL:ALL)/%wheel ALL=(ALL:ALL)/g' /mnt/etc/sudoers

echo -e "Configure system"
# set timezone
echo -e ".. Set timezone to America/Anchorage"
ln -sf /usr/share/zoneinfo/${TZ} /mnt/etc/localtime
arch-chroot /mnt hwclock --systohc
echo ${TZ} >> /mnt/etc/timezone

# generate locales for en_US
echo -e ".. Set locale to en_US"
sed -e 's/#en_US/en_US/g' -i /mnt/etc/locale.gen
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
arch-chroot /mnt locale-gen

# set keyboard
echo -e ".. Set keyboard"
echo "FONT=ter-132n" >> /etc/vconsole.conf

# set hostname
echo -e ".. Set hostname & network manager"
echo $HOSTNAME > /mnt/etc/hostname
echo "127.0.1.1 localhost $HOSTNAME.localdomain    $HOSTNAME" >> /mnt/etc/hosts
echo "::1 localhost $HOSTNAME" >> /mnt/etc/hosts

if [ -d /mnt/home/$NEWUSER ]; then
  mv /mnt/home/$NEWUSER /mnt/home/$NEWUSER-old
fi

# cryptfile to decrypt data
echo -e ".. Add cryptkey to data partition"
dd if=/dev/urandom of=/mnt/etc/cryptfs.key bs=1024 count=1
chmod 600 /mnt/etc/cryptfs.key 
CRYPTUUID=$(cryptsetup luksDump /dev/disk/by-partlabel/CRYPTDATA | grep UUID | cut -f2- -d: | sed -e 's/^[ \t]*//')
echo -en $PASSWORD | cryptsetup luksAddKey /dev/disk/by-uuid/$CRYPTUUID /mnt/etc/cryptfs.key 

echo -e ".. Chroot to /mnt"
arch-chroot /mnt /bin/zsh


# ## Tuning
# echo -e ""
# echo -e ".. generic tuning"
# wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/config/X1yoga6-01-generic_config-V2.sh
# chmod +x generic_config-V2.sh
# cp generic_config-V2.sh /mnt/ 
# arch-chroot /mnt ./generic_config-V2.sh $PWD $USER adak
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