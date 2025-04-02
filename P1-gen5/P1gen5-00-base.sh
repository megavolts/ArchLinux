# /bin/bash
# Dual boot with windows
# With 2 DISK
# Linux/Data Disk: /dev/nvme1n1
#  1            2048         1050623   512.0 MiB   EF00  EFI2
#  2         1050624       537921535   256.0 GiB   8300  CRYPTROOT
#  3       537921536      7814035455     3.4 TiB   8300  CRYPTDATA
# Windows Disk: /dev/nvme0n1

HOSTNAME=atka
WINDISK=/dev/nvme0n1
WINBOOTPART=1
DISK=/dev/nvme1n1
NEWUSER=megavolts
BOOTPART=1
ROOTPART=2
DATAPART=3
NEWINSTALL=false

NTFSDATA=false
WIPEROOT=true
WIPEDATA=false

TZDATA=America/Anchorage
echo 'Enter a default passphrase use to encrypt the disk and serve as password for root and megavolts:'
stty -echo
read PASSWORD
stty echo

echo -e "DISKS PREPARATION"
echo -e "ROOT partition"
if $NEWINSTALL
then
  echo ".. New installation, create new partition table"
  sgdisk -n $ROOTPART:1050624:537921535 -t $ROOTPART:8300 -c $ROOTPART:"CRYPTROOT" $DISK

  # echo -e ".. prepare boot partition"
  mkfs.fat -F32 ${DISK}${BOOTPART} -n EFIARCH

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

  mount /dev/mapper/root /mnt
  if [ -d /mnt/@root ]
    mv /mnt/@root /mnt/@root.old
  fi
  umount /dev/mapper/root
fi

echo -e "DATA partition"
if $WIPEDATA
  echo -e "... Encrypt data partition"
  echo -en $PASSWORD | cryptsetup luksFormat ${DISK}p${DATAPART} -q
  echo -e "... Decrypt data partition"
  echo -en $PASSWORD | cryptsetup luksOpen /dev/disk/by-partlabel/DATAPART data
  mkfs.btrfs --force --label arch /dev/mapper/data
else
  echo -en $PASSWORD | cryptsetup luksOpen ${DISK}p${DATAPART} data
fi

echo -e "EFI partition"
echo -e "... Wiping EFI partition"
mkfs.fat -F32 ${DISK}p${BOOTPART} -n EFIARCH

echo -e ".. Mount root btrfs subvolume on /mnt"
mount -o defaults,compress=zstd,noatime,nodev /dev/mapper/root /mnt/

if $WIPEROOT; then
  btrfs subvolume delete /mnt/{@tmp,@var_log,@var_tmp,@var_abs,@var_cache_pacman_pkg,@swap}
  if [ -d /mnt/root/@snapshots/ ]; then
  echo -e "... Delete individual root snapshots on  @root_snaps"
  btrfs subvolume delete /mnt/@snapshots/@root_snaps/*/snapshot 
  btrfs subvolume delete /mnt/@snapshots/@root_snaps/
  btrfs subvolume delete /mnt/@snapshots/
  fi  
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

echo -e ".. Mount data btrfs subvolume on /mnt/data"
if $WIPEDATA
  mkdir -p /mnt/data 
  mount -o defaults,compress=zstd,noatime,nodev,ssd,discard /dev/mapper/data /mnt/data
  echo -e "... create new home, data and snapshots suvolume"
  btrfs subvolume create /mnt/data/@home
  btrfs subvolume create /mnt/data/@data
  umount /mnt{/data,/}
fi

echo -e ".. mount root subvolume for install"
# Mount root subvolume
# By default zstd compression level is 3, but need to override default zlib compression algorithm
# By default space_cache option is v2 (free space tree) since btrfs-progs 5.15
# By default discard=async is automatically enable for kernel>6.2
# By default btrfs enable or disable ssd according to `/sys/block/DEV/queue/rotational`
mount -o defaults,compress=zstd,noatime,nodev,nodatacow,subvol=@root /dev/mapper/root /mnt/

# Mount root and data btrfs root volume
mkdir -p /mnt/storage/btrfs/{root,data}
mount -o defaults,compress=zstd,noatime,nodev /dev/mapper/root /mnt/storage/btrfs/root
mount -o defaults,compress=zstd,noatime,nodev /dev/mapper/data /mnt/storage/btrfs/data

echo -e ".. create and activate swapfile"
# Create swapfile if not existing
btrfs subvolume create /mnt/storage/btrfs/root/@swap
btrfs filesystem mkswapfile --size=64G /mnt/storage/btrfs/root/@swap/swapfile
swapon /mnt/storage/btrfs/root/@swap/swapfile
RESUME_OFFSET=$(btrfs inspect-internal map-swapfile -r /mnt/storage/btrfs/root/@swap/swapfile)

echo -e ".. create root subvolume mountpoints"
mkdir -p /mnt/{boot,.bootwin,bootbkp,tmp,var/log,var/tmp,var/abs,var/cache/pacman/pkg,home,storage/data}
mount -o defaults,compress=zstd,noatime,nodev,nodatacow,subvol=@tmp /dev/mapper/root /mnt/tmp
mount -o defaults,compress=zstd,noatime,nodev,nodatacow,subvol=@var_log /dev/mapper/root /mnt/var/log
mount -o defaults,compress=zstd,noatime,nodev,nodatacow,subvol=@var_tmp /dev/mapper/root /mnt/var/tmp
mount -o defaults,compress=zstd,noatime,nodev,nodatacow,subvol=@var_abs /dev/mapper/root /mnt/var/abs
mount -o defaults,compress=zstd,noatime,nodev,nodatacow,subvol=@var_cache_pacman_pkg /dev/mapper/root /mnt/var/cache/pacman/pkg
mount -o defaults,compress=zstd,noatime,nodev,subvol=@home /dev/mapper/data /mnt/home
mount -o defaults,compress=zstd,noatime,nodev,subvol=@data /dev/mapper/data /mnt/storage/data

# boot partition EFI and EFI_LINUX
echo -e ".. mount linux disk boot partition to /mnt/boot"
mount /dev/disk/by-label/EFIARCH /mnt/boot
echo -e ".. mount windows disk boot partition to /mnt/.boot"
mount /dev/disk/by-label/EFI /mnt/.bootwin
# copy any windows boot information from EFI to EFIARCH
rsync /mnt/.bootwin/ /mnt/boot -hAr --info=progress2
# remove intel-ucode if present
if [ -f /mnt/boot/intel-ucode.img ]
then
  rm /mnt/boot/intel-ucode.img
fi

echo -e "Arch Linux Installation"
echo -e "... Enable parallel download"
sed -i 's|#ParallelDownloads|ParallelDownloads|' /etc/pacman.conf
echo -e ".. Install base packages"
pacman -Sy
pacstrap /mnt base linux-zen linux-zen-headers base-devel openssh sudo ntp wget grml-zsh-config btrfs-progs networkmanager usbutils linux-firmware sof-firmware yajl mkinitcpio git go nano zsh terminus-font refind intel-ucode rsync iwd dhcpcd

# Enable unified 
echo -e ".. Istall basic tools"
pacstrap /mnt plocate acl util-linux fwupd arp-scan htop lsof strace screen refind terminus-font sudo

echo -e "... [config] plocate: includes btrfs mountpoints when updateding the database"
sed -i 's|PRUNE_BIND_MOUNTS = "yes"|PRUNE_BIND_MOUNTS = "no"|' /mnt/etc/updatedb.conf

echo -e ".. Create fstab"
genfstab -L -p /mnt >> /mnt/etc/fstab
sed 's/\/mnt\/swap/\/swap/g' /mnt/etc/fstab

# echo -e "... Add tmpfs to fstab"
# echo "tmpfs   /tmp    tmpfs  rw,nr_inodes=5k,noexec,nodev,nosuid,uid=user,gid=group,mode=1700 0 0" >> /mnt/etc/fstab

echo -e " .. Allow wheel group to sudo"
sed -i 's/# %wheel ALL=(ALL:ALL)/%wheel ALL=(ALL:ALL)/g' /mnt/etc/sudoers

echo -e "Configure system"
# set timezone
echo -e ".. Set timezone to America/Anchorage"
ln -sf /usr/share/zoneinfo/${TZDATA} /mnt/etc/localtime
arch-chroot /mnt hwclock --systohc
echo ${TZDATA} >> /mnt/etc/timezone

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