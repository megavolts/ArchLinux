
############################################################

echo -e "Tuning pacman"
echo -e ".. Enable multilib"
sed -i 's|#[multilib]|[multilib]|' /etc/pacman.conf
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
sed -i 's|#ParallelDownloads|ParallelDownloads|' /etc/pacman.conf

echo -e ".. Update pacman and system "
pacman -Syy
pacman -S --noconfirm archlinux-keyring
pacman-key --init
pacman-key --populate archlinux
pacman -Syu --noconfirm

echo -e ".. Optimize mirrorlist"
pacman -S --noconfirm reflector
sed -i "s|# --country France,Germany|--country USA,Switzerland|g" /etc/xdg/reflector/reflector.conf
systemctl enable --now reflector.timer

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
yays(){sudo -u megavolts yay -S --removemake --cleanafter --noconfirm $1}
############################################################
# ROOT options
echo -e "Set root password"
passwd root << EOF
$PASSWORD
$PASSWORD
EOF
chsh -S $(which zsh)

# USER options
echo -e "Set up user $NEWUSER"
echo -e ".. create $NEWUSER with default password"
useradd -m -g users -G wheel,audio,disk,lp,network -s /bin/zsh $NEWUSER
passwd $NEWUSER << EOF
$PASSWORD
$PASSWORD
EOF

echo -e ".. sync older directory to new directory for $NEWUSER"
# Sync old NEWUSER directory to new NEWUSER directory
if [ -d /home/$NEWUSER-old ]; then
  rsync -a $NEWUSER-old/ $NEWUSER/ -h --info=progress2 --remove-source-files
  find $NEWUSER-old -type d -empty -delete
fi

# Enable base service
echo -e ".. Start services"
systemctl enable NetworkManager
systemctl enable sshd
systemctl enable btrfs-scrub@home.timer 
systemctl enable btrfs-scrub@-.timer 
systemctl enable --now fstrim.timer

updatedb

echo -e ".. Set up crupttab to unlock data"
DATAUUID=$(cryptsetup luksDump /dev/disk/by-partlabel/CRYPTDATA | grep UUID | cut -f2- -d: | sed -e 's/^[ \t]*//')
echo "data   UUID=$DATAUUID  /etc/cryptfs.key" >> /etc/crypttab


## P1 specific software
echo -e "Graphic interface"
echo -e ".. Install drivers specific to Intel Corporation Alder Lake-P Integrated Graphics Controller"
pacman -S --noconfirm mesa vulkan-intel vulkan-mesa-layers
# Enable GuC/HuC firmware loading
echo "options i915 enable_guc=2" >> /etc/modprobe.d/i915.conf
mkinitcpio -p linux-zen 

# Configure kernel
# add btrfs hook and remove fsck
sed -i 's/fsck)/btrfs)/g' /etc/mkinitcpio.conf

# add encrypt and keyboard hook before filesystems
sed -i 's/udev autodetect/udev keyboard encrypt resume filesystems autodetect/g' /etc/mkinitcpio.conf
sed -i 's/kms keyboard keymap/kms keymap/g' /etc/mkinitcpio.conf
sed -i 's/block filesystems btrfs/block btrfs/g' /etc/mkinitcpio.conf

# Configure boot
ROFFSET=$(btrfs inspect-internal map-swapfile -r /mnt/btrfs/root/@swapfile)
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
Exec = /usr/bin/rsync -avh --delete /boot /.bootbkp && /usr/bin/rsync -avh --delete /boot /.boot
EOF

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
# copy btrfs volume support
cp /usr/share/refind/drivers_x64/btrfs_x64.efi /boot/EFI/refind/drivers_x64

# Rebuild kernel
if [ -f /boot/vmlinuz-linux ]; then
	mkinitcpio -p linux
fi
if [ -f /boot/vmlinuz-linux-zen ]; then
	mkinitcpio -p linux-zen
fi




exit
swapoff /mnt/mnt/btrfs/root/@swapfile
umount /mnt/{boot,.boot,data,mnt/data,mnt/btrfs/root,mnt/btrfs/data,var/log,var/tmp,/tmp,/var/cache/pacman/pkg,var/abs,home/$NEWUSER/.cache/yay,/home}
reboot