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
if $NEWINSTALL
then
  echo ".. New installation, create new partition table"
else
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
  echo -en $PASSWORD | cryptsetup luksOpen ${DISK}p${DATAPART} data
fi

echo -e ".. Mount root btrfs subvolume on /mnt"
mount -o defaults,compress=zstd:3,noatime,nodev,ssd,discard /dev/mapper/root /mnt/

if $WIPEROOT; then
  btrfs subvolume delete /mnt/{@beesroot,@beesdata,@tmp,@var_log,@var_tmp,@var_abs,@var_cache_pacman_pkg,@snapshot,@swap}
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

echo -e ".. Mount data btrfs subvolme on /mnt/data"
mkdir -p /mnt/data 
mount -o defaults,compress=zstd:3,noatime,nodev,ssd,discard /dev/mapper/data /mnt/data

if $WIPEROOT
  echo -e "... Delete old @root_snaps and recreating it"
  if [ ! -d /mnt/data/@snapshots/ ]; then
    btrfs subvolume create /mnt/data/@snapshots
  else
    btrfs subvolume delete /mnt/data/@snapshots/@root_snaps
  fi
  btrfs subvolume create /mnt/data/@snapshots/@root_snaps
fi

if $WIPEDATA
  echo -e "... create new home, data and snapshots suvolume"
  btrfs subvolume create /mnt/data/@home

  btrfs subvolume create /mnt/data/@data
  if [ ! -d /mnt/data/@snapshots/ ]; then
    btrfs subvolume create /mnt/data/@snapshots
  fi
  if [ ! -d /mnt/data/@snapshots/@root_snaps ]; then
    btrfs subvolume create /mnt/data/@snapshots/@root_snaps
  fi
  btrfs subvolume create /mnt/data/@snapshots/@home_snaps  
  btrfs subvolume create /mnt/data/@snapshots/@data_snaps  
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
btrfs filesystem mkswapfile --size=64G /mnt/mnt/btrfs/root/swapfile
swapon /mnt/mnt/btrfs/root/swapfile
RESUME_OFFSET=$(btrfs inspect-internal map-swapfile -r /mnt/mnt/btrfs/root/@swapfile)

echo -e ".. create root subvolume mountpoints and mount"
mkdir -p /mnt/{boot,.boot,tmp,var/log,var/tmp,var/abs,var/cache/pacman/pkg,home,mnt/data}
mount -o defaults,compress=zstd:3,noatime,nodev,nodatacow,ssd,discard,subvol=@tmp /dev/mapper/root /mnt/tmp
mount -o defaults,compress=zstd:3,noatime,nodev,nodatacow,ssd,discard,subvol=@var_log /dev/mapper/root /mnt/var/log
mount -o defaults,compress=zstd:3,noatime,nodev,nodatacow,ssd,discard,subvol=@var_tmp /dev/mapper/root /mnt/var/tmp
mount -o defaults,compress=zstd:3,noatime,nodev,nodatacow,ssd,discard,subvol=@var_abs /dev/mapper/root /mnt/var/abs
mount -o defaults,compress=zstd:3,noatime,nodev,nodatacow,ssd,discard,subvol=@var_cache_pacman_pkg /dev/mapper/root /mnt/var/cache/pacman/pkg
mount -o defaults,compress=zstd:3,noatime,nodev,ssd,discard,space_cache=v2,subvol=@home /dev/mapper/data /mnt/home
mount -o defaults,compress=zstd:3,noatime,nodev,ssd,discard,space_cache=v2,subvol=@data /dev/mapper/data /mnt/mnt/data

echo -e ".. mount windows disk boot partition to /mnt/boot"
mount ${WINDISK}p${WINBOOTPART} /mnt/boot
echo -e ".. mount linux disk boot partition to /mnt/.boot"
mount ${DISK}p${BOOTPART} /mnt/.boot

echo -e "Arch Linux Installation"
echo -e ".. Install base packages"
pacman -Sy
pacman -S --noconfirm archlinux-keyring
pacstrap /mnt base linux-zen linux-zen-headers base-devel openssh sudo ntp wget grml-zsh-config btrfs-progs networkmanager usbutils linux-firmware sof-firmware yajl mkinitcpio git go nano zsh terminus-font refind intel-ucode rsync

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
arch-chroot /mnt pacman -S --noconfirm terminus-font
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
chmod 600 /mntetc/cryptfs.key 
CRYPTUUID=$(cryptsetup luksDump /dev/disk/by-partlabel/CRYPTDATA | grep UUID | cut -f2- -d: | sed -e 's/^[ \t]*//')
echo -en $PASSWORD | cryptsetup luksAddKey /dev/disk/by-uuid/$CRYPTUUID /etc/cryptfs.key 

echo -e ".. Chroot to /mnt"
arch-chroot /mnt /bin/zsh

############################################################

echo -e "Tuning pacman"
echo -e ".. > Adding multilib"
sed -i 's|#[multilib]|[multilib]|' /etc/pacman.conf
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
sed -i 's|#ParallelDownloads|ParallelDownloads|' /etc/pacman.conf
echo -e ".. update pacman and system "

echo -e ".. update pacman and system "
pacman -Syy
pacman -S --noconfirm archlinux-keyring
pacman-key --init
pacman-key --populate archlinux
pacman -Syu --noconfirm

############################################################
# create $USER
echo -e "Set root password"
passwd root << EOF
$PASSWORD
$PASSWORD
EOF
chsh -S $(which zsh)

echo -e "Set up user $NEWUSER"
echo -e ".. create $NEWUSER with default password"
useradd -m -g users -G wheel,audio,disk,lp,network -s /bin/zsh $NEWUSER
passwd $NEWUSER << EOF
$PASSWORD
$PASSWORD
EOF
echo -e ".. create noCOW directory for $NEWUSER"

# Disable COW for thunderbird and baloo, thunderbird, bridge and yay
mkdir -p /home/$NEWUSER/.thunderbird
chattr +C /home/$NEWUSER/.thunderbird
mkdir -p /home/$NEWUSER/.local/share/baloo/
chattr +C /home/$NEWUSER/.local/share/baloo/
mkdir -p /home/$NEWUSER/.config/protonmail/bridge/cache 
chattr +C /home/$NEWUSER/.config/protonmail/bridge/cache
mkdir -p /home/$NEWUSER/.cache/yay
chattr +C /home/$NEWUSER/.cache/yay

btrfs subvolume create /mnt/btrfs/root/@yay
mount -o rw,noatime,ssd,discard,space_cache=v2,commit=120,nodatacow,subvol=@yay /dev/mapper/root /home/$NEWUSER/.cache/yay
echo "# megavolts btrfs nocow yay subvolume" >> /etc/fstab
echo "LABEL=arch     /home/$NEWUSER/.cache/yay    btrfs    rw,noatime,ssd,discard,space_cache=v2,commit=120,nodatacow,subvol=@yay    0 0" >> /etc/fstab

echo -e ".. sync older directory to new directory for $NEWUSER"
# Sync old NEWUSER directory to new NEWUSER directory
if [ -d /home/$NEWUSER-old ]; then
  rsync -a $NEWUSER-old/ $NEWUSER/ -h --info=progress2 --remove-source-files
  find $NEWUSER-old -type d -empty -delete
fi

echo -e "Install aur package manager"
# create a fake builduser
buildpkg(){
  CURRENT_DIR=$pwd
  wget https://aur.archlinux.org/cgit/aur.git/snapshot/$1.tar.gz
  tar -xvzf $1.tar.gz -C /home/$NEWUSER
  chown ${NEWUSER}:users /home/$NEWUSER/$1 -R
  cd /home/$NEWUSER/$1
  sudo -u $NEWUSER bash -c "makepkg -s --noconfirm"
  pacman -U --noconfirm $1*.zst
  cd $CURRENT_dir
  rm /home/$NEWUSER/$1/ -r
}

buildpkg package-query
buildpkg yay


echo -e ".. Start services"
systemctl enable NetworkManager
systemctl enable sshd
systemctl enable btrfs-scrub@home.timer 
systemctl enable btrfs-scrub@-.timer 

echo -e ".. Set up crupttab to unlock data"
DATAUUID=$(cryptsetup luksDump /dev/disk/by-partlabel/CRYPTDATA | grep UUID | cut -f2- -d: | sed -e 's/^[ \t]*//')
echo "data   UUID=$DATAUUID  /etc/cryptfs.key" >> /etc/crypttab

# add btrfs hook and remove fsck
sed -i 's/fsck)/btrfs)/g' /etc/mkinitcpio.conf

# add encrypt and keyboard hook before filesystems
sed -i 's/udev autodetect/udev keyboard encrypt resume filesystems autodetect/g' /etc/mkinitcpio.conf
sed -i 's/kms keyboard keymap/kms keymap/g' /etc/mkinitcpio.conf
sed -i 's/block filesystems btrfs/block btrfs/g' /etc/mkinitcpio.conf

# modify refind.conf
ROFFSET=$(btrfs inspect-internal map-swapfile -r /mnt/btrfs/root/@swapfile)
ROOTUUID=$(cryptsetup luksDump /dev/disk/by-partlabel/CRYPTROOT | grep UUID | cut -f2- -d: | sed -e 's/^[ \t]*//')

pacman -S --noconfirm refind
refind-install
refind-install --usedefault ${WINDISK}p${WINBOOTPART}
if [! $NEWINSTALL ]; then
  if [-d boot/refind_linux.conf ]; then
    cp /boot/refind_linux.conf /boot/refind_linux.conf.old
  fi
  wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/X1yoga6/sources/refind.conf -O /boot/refind_linux.conf
  sed -i "s|ROFFSET|$ROFFSET|g" /boot/refind_linux.conf
  sed -i "s|n1p5|n1p${ROOTPART}|g" /boot/refind_linux.conf
  sed -i "s|ROOTUUID|${ROOTUUID}|g" /boot/refind_linux.conf
fi

# Rebuild kernel
if [ -f /boot/vmlinuz-linux ]; then
	mkinitcpio -p linux
fi
if [ -f /boot/vmlinuz-linux-zen ]; then
	mkinitcpio -p linux-zen
fi

# copy btrfs volume support
cp /usr/share/refind/drivers_x64/btrfs_x64.efi /boot/EFI/refind/drivers_x64

# Copy partition on kernel update to enable backup to /.boot
cat << EOF >>  /usr/share/libalpm/hooks/91-boot_backup_after.hook
[Trigger]
Type = Path
Operation = Install
Operation = Upgrade
Target = usr/lib/modules/*/vmlinuz
Target = usr/lib/initcpio/*
Target = usr/src/*/dkms.conf

[Action]
Depends = rsync
Description = Backing up /boot...
When = PostTransaction
Exec = /usr/bin/rsync -avh --delete /boot /.bootbkp
Exec = /usr/bin/rsync -avh --delete /boot /.boot
EOF

mkdir /.bootbkp

rsync /boot/ /.boot/ -avh --info=progress2 
exit
swapoff /mnt/mnt/btrfs/root/@swapfile
umount /mnt/{boot,.boot,data,mnt/data,mnt/btrfs/root,mnt/btrfs/data,var/log,var/tmp,/tmp,/var/cache/pacman/pkg,var/abs,home/$NEWUSER/.cache/yay,/home}
reboot

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