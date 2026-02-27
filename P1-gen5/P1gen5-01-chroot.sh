
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
sed -i 's|#color|color|' /etc/pacman.conf

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


echo -e ".. Set up crypttab to unlock data"
DATAUUID=$(cryptsetup luksDump /dev/disk/by-partlabel/CRYPTDATA | grep UUID | cut -f2- -d: | sed -e 's/^[ \t]*//')
echo "data   UUID=$DATAUUID  /etc/cryptfs.key" >> /etc/crypttab

## Intel Graphics Software
echo -e "Graphic interface"
echo -e ".. Install drivers specific to Intel Corporation Alder Lake-P Integrated Graphics Controller"
pacman -S --noconfirm mesa vulkan-intel vulkan-mesa-layers intel-media-driver
# Enable GuC/HuC firmware loading
echo "options i915 enable_guc=3" >> /etc/modprobe.d/i915.conf


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
Exec = /usr/bin/rsync -avh --delete /boot/ /.bootbkp && /usr/bin/rsync -avh --delete /boot/ /.bootwin
EOF


exit
swapoff /mnt/storage/btrfs/root/@swap/swapfile
umount /mnt/{boot,.bootwin,storage,storage/data,storage/btrfs/root,storage/btrfs/data,var/log,var/tmp,/tmp,/var/cache/pacman/pkg,var/abs,/home}
reboot