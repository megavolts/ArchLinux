
############################################################
NEWUSER=megavolts
WINDATAPART=/dev/disk/by-label/WinData
WINBOOTPART=/dev/disk/by-label/EFI
NUXBOOTPART=/dev/disk/by-label/EFIARCH

echo -e "Check doas configuration"

echo -e "Tuning pacman"
echo -e ".. Enable multilib" 
sed -i 's|#[multilib]|[multilib]|' /etc/pacman.conf
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
sed -i 's|#ParallelDownloads|ParallelDownloads|' /etc/pacman.conf
sed -i 's|#Color|Color|' /etc/pacman.conf

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

echo -e "Install aur package manager"
# create a fake builduser
buildpkg(){
  CURRENT_DIR=$pwd
  wget https://aur.archlinux.org/cgit/aur.git/snapshot/$1.tar.gz
  tar -xvzf $1.tar.gz -C /home/$NEWUSER
  chown ${NEWUSER}:users /home/$NEWUSER/$1 -R
  cd /home/$NEWUSER/$1
  doas -u $NEWUSER bash -c "makepkg -s --noconfirm"
  pacman -U --noconfirm $1*.zst
  cd $CURRENT_dir
  rm /home/$NEWUSER/$1/ -r
}

buildpkg package-query
buildpkg yay
yays(){doas -u $NEWUSER bash -c "yay -S --removemake --cleanafter --noconfirm $1"}

############################################################
echo -e ".. sync older directory to new directory for $NEWUSER"
# {}
# # Sync old NEWUSER directory to new NEWUSER directory
# NEED TO MAKE SURE NO TO COPY hiddne file
# if [ -d /home/$NEWUSER-old ]; then
#   rsync -a /home/$NEWUSER-old/ /home/$NEWUSER/ -h --info=progress2 --remove-source-files
#   find /home/$NEWUSER-old -type d -empty -delete
# fi

## FOR P1 only
echo -e ".. Set up crypttab to unlock data"
DATAUUID=$(cryptsetup luksDump /dev/disk/by-partlabel/CRYPTDATA | grep UUID | cut -f2- -d: | sed -e 's/^[ \t]*//')
echo "data   UUID=$DATAUUID  /etc/cryptfs.key" >> /etc/crypttab

## Intel Graphics Software
echo -e "Graphic interface"
echo -e ".. Install drivers specific to Intel Corporation Alder Lake-P Integrated Graphics Controller"
pacman -S --noconfirm mesa vulkan-intel vulkan-mesa-layers intel-media-driver
# Enable GuC/HuC firmware loading
echo "options i915 enable_guc=3" >> /etc/modprobe.d/i915.conf

# Disable build of debug packages
echo -e "... disable build of debug packge when using makepkg"
sed -i "s| debug lto| \!debug lto|g" /etc/makepkg.conf


## Install liminie helper
yays  limine-mkinitcpio-hook
# TODO MORE

#pacman -S --noconfirm nvidia-open nvidia-prime

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
Exec = /bin/sh -c "/usr/bin/rsync -avh --delete /efi /.efibkp && /usr/bin/rsync -avh --delete /efi /.efiwin"
EOF

<<<<<<< HEAD
# refind-install --usedefault $WINBOOTPART
# refind-install --usedefault $NUXBOOTPART

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

=======
>>>>>>> 89f5fb102d1c316f836031c297fc51af7dc3c19a
exit

swapoff /mnt/storage/btrfs/root/@swap/swapfile
umount /mnt/{boot,.bootwin,storage,storage/data,storage/btrfs/root,storage/btrfs/data,var/log,var/tmp,/tmp,/var/cache/pacman/pkg,var/abs,/home}
reboot
