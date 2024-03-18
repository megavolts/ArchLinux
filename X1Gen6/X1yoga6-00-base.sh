
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
INSTALL=True
NTFSDATA=True
WIPEDISK=True
TZDATA=America/Anchorage
echo 'Enter a default passphrase use to encrypt the disk and serve as password for root and megavolts:'
stty -echo
read PASSWORD
stty echo


if $INSTALL
then
  sgdisk -n $ROOTPART:315654144:3907029134 -t $ROOTPART:8300 -c $ROOTPART:"CRYPTARCH" $DISK

  # echo -e ".. prepare boot partition"
  # mkfs.fat -F32 ${DISK}${BOOTPART}

  echo -e ".. wipe partition"
  # Wipe partition with zeros after creating an encrypted container with a random key
  cryptsetup open --type plain ${DISK}p$BOOTPART container --key-file /dev/urandom 
  dd if =/dev/zero of=/dev/mapper/container status=progress bs=1M
  cryptsetup close container
  echo -e ".. encrypting root partition"
  echo -en $PASSWORD | cryptsetup luksFormat --align-payload=4096 -s 512 -c aes-xts-plain64 /dev/disk/by-partlabel/CRYPTARCH -q
  echo -en $PASSWORD | cryptsetup luksOpen /dev/disk/by-partlabel/cryptarch arch
  mkfs.btrfs --force --label arch /dev/mapper/arch
else
  echo -en $PASSWORD | cryptsetup luksOpen /dev/disk/by-partlabel/CRYPTARCH arch
  if $WIPEDISK
      echo -e ".. wipe partition"
      dd if=/dev/zero of=/dev/mapper/arch status=progress bs=1M
      echo -e ".. encrypting root partition"
      echo -en $PASSWORD | cryptsetup luksFormat --align-payload=4096 /dev/disk/by-partlabel/cryptarch -q
      echo -en $PASSWORD | cryptsetup luksOpen /dev/disk/by-partlabel/cryptarch arch
      mkfs.btrfs --force --label arch /dev/mapper/arch
  fi
fi

echo -e ".. create subvolumes"
mount -o defaults,compress=lzo,noatime,nodev,ssd,discard /dev/mapper/arch /mnt/

if $INSTALL or $WIPEDISK
then
  echo -e "... create new root, var and tmp subvolume"
  btrfs subvolume create /mnt/@root
  btrfs subvolume create /mnt/@home
  btrfs subvolume create /mnt/@data
else
  # move old root subvolume
  mv /mnt/@root /mnt/@root_old

  # preserve home and data subvolume, delete other
  btrfs subvolume delete /mnt/{@tmp,@var_log,@var_tmp,@var_cache}

  echo -e "... create new root"
  # create new root subvolume
  btrfs subvolume create /mnt/@root
fi
  
# create necssary subvolume
# arch wiki recommentd
btrfs subvolume create /mnt/@var_log
# to prevent slowdown
btrfs subvolume create /mnt/@var_tmp  
btrfs subvolume create /mnt/@var_cache # use to only create subvolume for /var/cache/pacman/pkg
btrfs subvolume create /mnt/@opt  #/opt contains large softwares, and doens't need to be snapshotted


# create swapfile
btrfs filesystem mkswapfile --size=32G /mnt/@swapfile
mkswap /mnt/@swapfile

umount /mnt

# Mount subvolume
mount -o defaults,compress=lzo,noatime,ssd,discard,commit=120,subvol=@root /dev/mapper/arch /mnt
mkdir -p /mnt/home
mount -o defaults,compress=lzo,noatime,ssd,discard,subvol=@home /dev/mapper/arch /mnt/home
mkdir -p /mnt/mnt/data
mount -o defaults,compress=lzo,noatime,ssd,discard,subvol=@data /dev/mapper/arch /mnt/mnt/data
mkdir -p /mnt/var/{log,tmp}
mount -o defaults,compress=lzo,noatime,ssd,discard,subvol=@var_log /dev/mapper/arch /mnt/var/log
mount -o defaults,compress=lzo,noatime,ssd,discard,subvol=@var_tmp /dev/mapper/arch /mnt/var/tmp
mkdir -p /mnt/btrfs-arch/
mount -o defaults,compress=lzo,noatime,ssd,discard /dev/mapper/arch /mnt/mnt/btrfs-arch
swapon /mnt/mnt/btrfs-arch/@swapfile

##
echo -e "prepare disk for installation"
if INSTALL
then
  mkfs.vfat -F32 ${DISK}$BOOTPART
fi
mkdir /mnt/boot
mount ${DISK}p$BOOTPART /mnt/boot

# Install Arch Linux
pacman -Sy
pacstrap  /mnt linux-zen linux-zen-headers base base-devel openssh sudo ntp wget grml-zsh-config btrfs-progs networkmanager usbutils util-linux linux-firmware sof-firmware yajl mkinitcpio git go nano zsh mlocaste

echo -e "Create fstab"
genfstab -L -p /mnt >> /mnt/etc/fstab

# add /tmp
echo "tmpfs   /tmp    tmpfs  rw,nr_inodes=5k,noexec,nodev,nosuid,uid=user,gid=group,mode=1700 0 0" >> /mnt/etc/fstab

# Allow wheel to use sudo
echo -e " .. > allowing wheel group to sudo"
sed -i 's/^#\s*\(%wheel\s\+ALL=(ALL\:ALL)\s\+ALL\)/\1/' /mnt/etc/sudoers

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
pacman -S terminus-font
echo "FONT=ter-132n" >> /etc/vconsole.conf

# set hostname
echo -e ".. > set hostname & network manager"
echo $HOSTNAME > /mnt/etc/hostname
echo "127.0.1.1 localhost $HOSTNAME.localdomain    $HOSTNAME" >> /mnt/etc/hosts
echo "::1 localhost $HOSTNAME" >> /mnt/etc/hosts

arch-chroot /mnt bin/zsh

echo -e "Tuning pacman"
echo -e ".. > Adding multilib"
sed -i 's|#[multilib]|[multilib]|' /etc/pacman.conf
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
sed -i 's|#ParallelDownloads|ParallelDownloads|' /etc/pacman.conf

echo -e ".. update pacman and system "
pacman -Syy
pacman -S --noconfirm archlinux-keyring
pacman-key --init
pacman-key --populate archlinux
pacman -Syu --noconfirm

# create $USER
echo -e "Setting up users"
echo -e ".. > setting root password"
passwd root << EOF
$PASSWORD
$PASSWORD
EOF
echo -e ".. > create user $NEWUSER with default password"
useradd -m -g users -G wheel,audio,disk,lp,network -s /bin/zsh $NEWUSER
passwd $NEWUSER << EOF
$PASSWORD
$PASSWORD
EOF

# Disable COW for thunderbird and baloo
mkdir -p /home/$NEWUSER/.thunderbird
chattr +C /home/$NEWUSER/.thunderbird
mkdir -p /home/$NEWUSER/.local/share/baloo/
chattr +C /home/$NEWUSER/.local/share/baloo/
mkdir -p /home/$NEWUSER/.config/protonmail/bridge/cache 
chattr +C /home/$NEWUSER/.config/protonmail/bridge/cache
mkdir -p /home/$NEWUSER/.cache/yay
chattr +C /home/$NEWUSER/.cache/yay

btrfs subvolume create /mnt/btrfs-arch/@yay
echo "# megavolts btrfs nocow yay subvolume" >> /etc/fstab
echo "LABEL=arch     /home/$NEWUSER/.cache/yay    btrfs    rw,noatime,ssd,discard,space_cache=v2,commit=120,nodatacow,subvol=@yay    0 0" >> /etc/fstab
systemctl daemon-reload && mount -a

echo -e ".. > Installing aur package manager"
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

echo -e ".. > start services"
systemctl enable NetworkManager
systemctl enable sshd
systemctl enable btrfs-scrub@home.timer 
systemctl enable btrfs-scrub@-.timer 

# add btrfs hook and remove fsck
sed -i 's/fsck)/btrfs)/g' /etc/mkinitcpio.conf

# add encrypt and keyboard hook before filesystems
sed -i 's/autodetect/autodetect keyboard encrypt resume filesystems/g' /etc/mkinitcpio.conf

# modify refind.conf
ROFFSET=$(btrfs inspect-internal map-swapfile -r /btrfs-arch/@swapfile)
if $INSTALL
then
  pacman -S refind
  refind-install
  cp /boot/refind_linux.conf /boot/refind_linux.conf.old
  wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/X1yoga6/sources/refind.conf -O /boot/refind_linux.conf
  sed -i "s|ROFFSET|$ROFFSET|g" /boot/refind_linux.conf
fi

# Rebuild kernel
if [ -f /boot/vmlinuz-linux ]; then
	mkinitcpio -p linux
fi
if [ -f /boot/vmlinuz-linux-zen ]; then
	mkinitcpio -p linux-zen
fi



exit
swapoff /mnt/btrfs-arch/@swapfile
umount /mnt/{boot,home,data,var/log,var/tmp,btrfs-arch}

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



