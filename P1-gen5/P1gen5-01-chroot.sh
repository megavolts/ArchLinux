
############################################################
NEWUSER=megavolts
WINDATAPART=/dev/disk/by-label/WinData
WINBOOTPART=/dev/disk/by-label/EFI
NUXBOOTPART=/dev/disk/by-label/EFIARCH


echo -e "Tuning pacman"
echo -e ".. Enable multilib" 
sed -i 's|#[multilib]|[multilib]|' /etc/pacman.conf
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
sed -i 's|#ParallelDownloads|ParallelDownloads|' /etc/pacman.conf

echo -e ".. Update pacman and system "
pacman -Syy
pacman -S --noconfirm archlinux-keyring rebuild-detector
pacman-key --init
pacman-key --populate archlinux
pacman -Syu --noconfirm

echo -e ".. Optimize mirrorlist"
pacman -S --noconfirm reflector
sed -i "s|# --country France,Germany|--country USA,Switzerland|g" /etc/xdg/reflector/reflector.conf
systemctl enable reflector.timer

############################################################
echo -e "Create user"
echo 'Enter a default passphrase use to encrypt the disk and serve as password for root and megavolts:'
stty -echo
read PASSWORD
stty echo
# ROOT options
echo -e "Set root password"
passwd root << EOF
$PASSWORD
$PASSWORD
EOF
chsh -s $(which zsh)

# USER options
echo -e "Set up user $NEWUSER"
echo -e ".. create $NEWUSER with default password"
useradd -m -g users -G wheel,audio,disk,lp,network -s /bin/zsh $NEWUSER
passwd $NEWUSER << EOF
$PASSWORD
$PASSWORD
EOF

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
yays(){sudo -u $NEWUSER yay -S --removemake --cleanafter --noconfirm $1}

############################################################
echo -e ".. sync older directory to new directory for $NEWUSER"
# {}
# # Sync old NEWUSER directory to new NEWUSER directory
# NEED TO MAKE SURE NO TO COPY hiddne file
# if [ -d /home/$NEWUSER-old ]; then
#   rsync -a /home/$NEWUSER-old/ /home/$NEWUSER/ -h --info=progress2 --remove-source-files
#   find /home/$NEWUSER-old -type d -empty -delete
# fi

# Enable base service
echo -e ".. Start services"
systemctl enable NetworkManager
systemctl enable sshd
systemctl enable btrfs-scrub@home.timer 
systemctl enable btrfs-scrub@-.timer 
systemctl enable fstrim.timer

echo -e ".. Set up crypttab to unlock data"
DATAUUID=$(cryptsetup luksDump /dev/disk/by-partlabel/CRYPTDATA | grep UUID | cut -f2- -d: | sed -e 's/^[ \t]*//')
echo "data   UUID=$DATAUUID  /etc/cryptfs.key" >> /etc/crypttab

## Intel Graphics Software
echo -e "Graphic interface"
echo -e ".. Install drivers specific to Intel Corporation Alder Lake-P Integrated Graphics Controller"
pacman -S --noconfirm mesa vulkan-intel vulkan-mesa-layers intel-media-driver
# Enable GuC/HuC firmware loading
echo "options i915 enable_guc=3" >> /etc/modprobe.d/i915.conf


pacman -S --noconfirm nvidia-open nvidia-prime

# Configure kernel
# add btrfs hook and remove fsck
sed -i 's/fsck)/btrfs)/g' /etc/mkinitcpio.conf

# add encrypt and keyboard hook before filesystems
sed -i 's/filesystems /encrypt resume filesystems /g' /etc/mkinitcpio.conf

# Configure boot
ROFFSET=$(btrfs inspect-internal map-swapfile -r /storage/btrfs/root/@swap/swapfile)
ROOTUUID=$(cryptsetup luksDump /dev/disk/by-partlabel/CRYPTROOT | grep UUID | cut -f2- -d: | sed -e 's/^[ \t]*//')

# Set up automatic copy of boot partition on kernel update to enable backup to /.boot
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
Exec = /usr/bin/rsync -avh --delete /boot/ /.bootbkp && /usr/bin/rsync -avh --delete /boot/ /.bootwin
EOF

refind-install --usedefault $WINBOOTPART
refind-install --usedefault $NUXBOOTPART

if [! $NEWINSTALL ]; then
  if [-d boot/refind_linux.conf ]; then
    cp /boot/refind_linux.conf /boot/refind_linux.conf.old
  fi
  wget https://raw.githubusercontent.com/megavolts/ArchLinux/refs/heads/master/X1Gen6/sources/refind.conf -O /boot/refind_linux.conf
  sed -i "s|ROFFSET|$ROFFSET|g" /boot/refind_linux.conf
  sed -i "s|ROOTUUID|${ROOTUUID}|g" /boot/refind_linux.conf
  cp /boot/refind_linux.conf /.bootwin/refind_linux.conf
fi

# copy btrfs volume support
mkdir -p /boot/EFI/tools/drivers_x64
cp /usr/share/refind/drivers_x64/btrfs_x64.efi /boot/EFI/tools/drivers_x64
cp /usr/share/refind/icons /boot/EFI/refind/ -R
mkdir -p /.bootwin/EFI/tools/drivers_x64
cp /usr/share/refind/drivers_x64/btrfs_x64.efi /.bootwin/EFI/tools/drivers_x64
cp /usr/share/refind/icons /.bootwin/EFI/refind/ -R

# Rebuild kernel
if [ -f /boot/vmlinuz-linux ]; then
	mkinitcpio -p linux
fi
if [ -f /boot/vmlinuz-linux-zen ]; then
	mkinitcpio -p linux-zen
fi

exit
swapoff /mnt/storage/btrfs/root/@swap/swapfile
umount /mnt/{boot,.bootwin,storage,storage/data,storage/btrfs/root,storage/btrfs/data,var/log,var/tmp,/tmp,/var/cache/pacman/pkg,var/abs,/home}
reboot