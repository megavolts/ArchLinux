# /bin/bash
# Dual boot with windows
# With 2 DISK
# Linux/Data Disk: /dev/nvme1n1
#  1            2048         1050623   512.0 MiB   EF00  EFI2
#  2         1050624       537921535   256.0 GiB   8300  CRYPTROOT
#  3       537921536      7814035455     3.4 TiB   8300  CRYPTDATA
# Windows Disk: /dev/nvme0n1

HOSTNAME=vouivre
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
  if [ -d /mnt/@ ]
    mv /mnt/@ /mnt/@.old
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
  btrfs subvolume delete /mnt/{@var_log,@var_cache,@root}
  if [ -d /mnt/root/@snapshots/ ]; then
  echo -e "... Delete individual root snapshots on  @root_snaps"
  btrfs subvolume delete /mnt/@snapshots/@root_snaps/*/snapshot 
  btrfs subvolume delete /mnt/@snapshots/@root_snaps/
  btrfs subvolume delete /mnt/@snapshots/
  fi  
fi

echo -e "... Create new root, var and tmp subvolume"
btrfs subvolume create /mnt/@ # Root directory
btrfs subvolume create /mnt/@var_log # Log files; avoid rollback for easier debugging
btrfs subvolume create /mnt/@var_cache # Cache files; no need to rollback
btrfs subvolume create /mnt/@root  # Root user's home directory


echo -e "... Unmount /dev/mapper/root"
umount /mnt

echo -e "... Mount subvolume for install"
# Mount root subvolume
# By default zstd compression level is 3, but need to override default zlib compression algorithm
# By default space_cache option is v2 (free space tree) since btrfs-progs 5.15
# By default discard=async is automatically enable for kernel>6.2
# By default btrfs enable or disable ssd according to `/sys/block/DEV/queue/rotational`
mount -o defaults,compress=zstd,noatime,nodev,subvol=@ /dev/mapper/root /mnt/

echo -e ".. create root subvolume mountpoints"
mkdir -p /mnt/{efi,.efiwin,var/log,var/cache,home,storage/{data,btrfs/{root,data}}}
mount -o defaults,compress=zstd,noatime,nodev,nodatacow,subvol=@var_log /dev/mapper/root /mnt/var/log
mount -o defaults,compress=zstd,noatime,nodev,nodatacow,subvol=@var_cache /dev/mapper/root /mnt/var/cache

# disable Copy-on-Write to prevent slowdown
mkdir -p /mnt/tmp
mkdir -p /mnt/var/{log,cache,tmp,abs,lib,lib/{docker,libvirt,containers}}
chattr +C /mnt/var/log
chattr +C /mnt/var/cache
chattr +C /mnt/var/tmp
chattr +C /mnt/var/abs
chattr +C /mnt/var/lib/docker
chattr +C /mnt/var/lib/libvirt
chattr +C /mnt/var/lib/containers
chattr +C /mnt/tmp

echo -e ".. Mount home and data btrfs subvolume respectively to /mnt/home and /mnt/data"
if $WIPEDATA
  mkdir -p /mnt/data 
  mount -o defaults,compress=zstd,noatime,nodev,ssd,discard /dev/mapper/data /mnt/data
  echo -e "... create new home, data and snapshots suvolume"
  btrfs subvolume create /mnt/data/@home
  btrfs subvolume create /mnt/data/@data
  umount /mnt{/data,/}
fi
mount -o defaults,compress=zstd,noatime,nodev,subvol=@home /dev/mapper/data /mnt/home
mount -o defaults,compress=zstd,noatime,nodev,subvol=@data /dev/mapper/data /mnt/storage/data


# Mount root and data btrfs root volume
mkdir -p /mnt/storage/btrfs/{root,data}
mount -o defaults,compress=zstd,noauto,noatime,nodev /dev/mapper/root /mnt/storage/btrfs/root
mount -o defaults,compress=zstd,noauto,noatime,nodev /dev/mapper/data /mnt/storage/btrfs/data

echo -e ".. create and activate swapfile"
# Create swapfile if not existing
btrfs subvolume create /mnt/storage/btrfs/root/@swap
btrfs filesystem mkswapfile --size=64G /mnt/storage/btrfs/root/@swap/swapfile
swapon /mnt/storage/btrfs/root/@swap/swapfile
RESUME_OFFSET=$(btrfs inspect-internal map-swapfile -r /mnt/storage/btrfs/root/@swap/swapfile)

# boot partition EFI and EFI_LINUX
echo -e ".. mount linux disk boot partition to /mnt/boot/efi"
mount /dev/disk/by-label/EFIARCH /mnt/efi
echo -e ".. mount windows disk boot partition to /mnt/boot/efiwin"
mount /dev/disk/by-label/EFI /mnt/.efiwin

# copy any windows boot information from EFI to EFIARCH
rsync /mnt/.bootwin/ /mnt/boot -hAr --info=progress2
# remove intel-ucode if present
if [ -f /mnt/boot/intel-ucode.img ]
then
  rm /mnt/boot/intel-ucode.img
fi
# remove previous kernel
rm -R /mnt/{efi,.efiwin}/EFI/Linux

echo -e "Arch Linux Installation"
echo -e "... Enable parallel download"
sed -i 's|#ParallelDownloads|ParallelDownloads|' /etc/pacman.conf
sed -i 's|#Color|Color|' /etc/pacman.conf

echo -e ".. Install base packages"
pacman -Sy
pacstrap /mnt base linux-zen linux-zen-headers base-devel openssh doas ntp wget grml-zsh-config btrfs-progs networkmanager usbutils linux-firmware sof-firmware yajl mkinitcpio git go nano zsh terminus-font refind intel-ucode rsync iwd dhcpcd

# Enable unified 
echo -e ".. Install basic tools"
pacstrap /mnt plocate acl util-linux fwupd arp-scan htop lsof strace screen refind terminus-font

echo -e "... [config] plocate: includes btrfs mountpoints when updateding the database"
sed -i 's|PRUNE_BIND_MOUNTS = "yes"|PRUNE_BIND_MOUNTS = "no"|' /mnt/etc/updatedb.conf
sed -i 's|\/media \/mnt|\/media \/mnt \/storage"|' /mnt/etc/updatedb.conf

echo -e ".. Create fstab"
genfstab -L -p /mnt >> /mnt/etc/fstab
sed 's/\/mnt\/swap/\/swap/g' /mnt/etc/fstab

# echo -e "... Add tmpfs to fstab"
# echo "tmpfs   /tmp    tmpfs  rw,nr_inodes=5k,noexec,nodev,nosuid,uid=user,gid=group,mode=1700 0 0" >> /mnt/etc/fstab

#echo -e " .. Allow wheel group for sudo"
#sed -i 's/# %wheel ALL=(ALL:ALL)/%wheel ALL=(ALL:ALL)/g' /mnt/etc/sudoers

echo -e " .. Allow wheel group for doas"
cat << EOF > /mnt/etc/doas.conf
permit setenv {PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin} :wheel
permit root as megavolts
EOF
chown -c root:root /mnt/etc/doas.conf
chmod -c 0400 /mnt/etc/doas.conf

arch-chroot /mnt if doas -C /etc/doas.conf; then echo "config ok"; else echo "config error"; fi

cat << EOF > /mnt/usr/local/bin/sudo
#!/bin/bash
exec doas "${@/--preserve-env*/}"
EOF


echo -e "Configure system"
# set timezone
echo -e ".. Set timezone to America/Anchorage"
ln -sf /usr/share/zoneinfo/${TZDATA} /mnt/etc/localtime
arch-chroot /mnt hwclock --systohc
echo ${TZDATA} >> /mnt/etc/timezone
echo "#KEYMAP=us" >> /mnt/etc/vconsole.conf

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

### USERS ###

echo -e "Create user"
echo 'Enter a default passphrase use to encrypt the disk and serve as password for root and megavolts:'
stty -echo
read PASSWORD
stty echo
# ROOT options
echo -e "Set root password"
arch-chroot /mnt passwd root << EOF
$PASSWORD
$PASSWORD
EOF
arch-chroot /mnt chsh -s $(which zsh)

# USER options
echo -e "Set up user $NEWUSER"
echo -e ".. create $NEWUSER with default password"
arch-chroot /mnt useradd -m -g users -G wheel,audio,disk,lp,network -s /bin/zsh $NEWUSER
arch-chroot /mnt passwd $NEWUSER << EOF
$PASSWORD
$PASSWORD
EOF
arch-chroot /mnt passwd root

# Unified kernel with systemd-boot
ROFFSET=$(btrfs inspect-internal map-swapfile -r /mnt/storage/btrfs/root/@swap/swapfile)
ROOTUUID=$(cryptsetup luksDump /dev/disk/by-partlabel/CRYPTROOT | grep UUID | cut -f2- -d: | sed -e 's/^[ \t]*//')

# Configure  cmdline
echo "loglevel=3" >> /mnt/etc/kernel/cmdline
echo "loglevel=4" >> /mnt/etc/kernel/cmdline
mkdir /mnt/etc/cmdline.d
echo "rd.luks.name=$ROOTUUID=root root=/dev/mapper/root rootfstype=btrfs rootflags=subvol=/@ rw resume=/dev/mapper/root resume_offset=$ROFFSET" >> /mnt/etc/cmdline.d/root.conf

# Adjust mkinitcpio.conf
# add sd-encrypt to hooks
sed -i 's/sd-vconsole /sd-vconsole sd-encrypt /g' /mnt/etc/mkinitcpio.conf

# Configure Unified Kernel Image UKI
sed -i 's/#ALL_config/ALL_config /g' /mnt/etc/mkinitcpio.d/linux-zen.preset
sed -i "s/('default')/('default' 'fallback')/g" /mnt/etc/mkinitcpio.d/linux-zen.preset

sed -i 's/default_image/#default_image/g' /mnt/etc/mkinitcpio.d/linux-zen.preset
sed -i 's/#default_uki/default_uki/g' /mnt/etc/mkinitcpio.d/linux-zen.preset
sed -i 's/#default_options/default_options/g' /mnt/etc/mkinitcpio.d/linux-zen.preset

sed -i 's/fallback_image/#fallback_image/g' /mnt/etc/mkinitcpio.d/linux-zen.preset
sed -i 's/#fallback_uki/fallback_uki/g' /mnt/etc/mkinitcpio.d/linux-zen.preset
sed -i 's/#fallback_options/fallback_options/g' /mnt/etc/mkinitcpio.d/linux-zen.preset

mkdir -p /mnt/efi/EFI/Linux

arch-chroot /mnt mkinitcpio -P

# Enable base service
echo -e ".. Start services"
systemctl --root /mnt enable NetworkManager
systemctl --root /mnt enable sshd
systemctl --root /mnt enable btrfs-scrub@home.timer 
systemctl --root /mnt enable btrfs-scrub@-.timer 
systemctl --root /mnt enable fstrim.timer

# Install systemd-boot Bootloader
arch-chroot /mnt bootctl install --esp-path=/efi

arch-chroot /mnt /bin/zsh

# TODO MEGE 01-chrrot here
#systemctl reboot

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