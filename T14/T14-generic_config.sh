#/bin/bash!
PASSWORD=$1
USER=$2
HOSTNAME=$3

echo -e "Tuning pacman"
echo -e ".. > Adding multilib"
sed -i 's|#[multilib]|[multilib]|' /etc/pacman.conf
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
echo -e ".. update pacman and system "
pacman -Syy
pacman -S --noconfirm archlinux-keyring
pacman-key --init
pacman-key --populate archlinux
pacman -Syu --noconfirm

echo -e ".. > Installing aur package manager"

# add megavolts users
echo -e ".. > create user $USER with default password"
useradd -m -g users -G wheel,audio,disk,lp,network -s /bin/zsh $USER
passwd megavolts << EOF
$PASSWORD
$PASSWORD
EOF


# create a fake builduser
buildpkg(){
  CURRENT_DIR=$pwd
  wget https://aur.archlinux.org/cgit/aur.git/snapshot/$1.tar.gz
  tar -xvzf $1.tar.gz -C /home/$USER
  chown ${USER}:users /home/$USER/$1 -R
  cd /home/$USER/$1
  sudo -u $USER bash -c "makepkg -s --noconfirm"
  pacman -U $1*.zst --noconfirm
  cd $CURRENT_dir 
  rm /home/$USER/$1 -R
}

echo -e " .. > allowing wheel group to sudo"
sed  's/# %wheel ALL=(ALL) ALL/%  wheel ALL=(ALL) ALL/' -s /etc/sudoers


buildpkg package-query
buildpkg yaourt

yaourtpkg() {
  sudo -u $USER bash -c "yaourt -S --noconfirm $1"
}

#echo -e ".. > Optimize mirrorlist"
#yaourtpkg reflector
#reflector --latest 200 --protocol http --protocol https --sort rate --save /etc/pacman.d/mirrorlist
#wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/X220/source/mirrorupgrade.hook -P /etc/pacman.d/hooks/

echo -e "Configure system"
echo "FONT=lat9w-16" >> /etc/vconsole.conf
echo -e ".. > changing locales"
wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/X220/source/locale.gen -O /etc/locale.gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
locale-gen
localectl set-locale LANG=en_US.UTF-8

echo -e ".. > set timezone to America/Anchorage"
timedatectl set-ntp 1
timedatectl set-timezone America/Anchorage

echo -e ".. > setting hostname & network manager"
hostnamectl set-hostname $HOSTNAME
echo "127.0.1.1    $HOSTNAME.localdomain    $HOSTNAME" >> /etc/hosts
echo $HOSTNAME > /etc/hostname

echo -e "Setting up users"
echo -e ".. > setting root password"
passwd root << EOF
$PASSWORD
$PASSWORD
EOF

chsh -s $(which zsh)

echo -e " .. > allowing wheel group to sudo"
sed  's/# %wheel ALL=(ALL) ALL/%  wheel ALL=(ALL) ALL/' -s /etc/sudoers

pacman -S mlocate --noconfirm

echo -e ".. > start services"
systemctl enable NetworkManager
systemctl enable sshd
updatedb
systemctl enable btrfs-scrub@home.timer 
systemctl enable btrfs-scrub@-.timer 

# uncomment in /etec/pam.d/sddm
# auth            optional        pam_gnome_keyring.so
# password        optional        pam_gnome_keyring.so use_authtok
# session         optional        pam_gnome_keyring.so auto_start


# deactivate baloo indexer
balooctl suspend
balooctl disable


## REMOVE UNDERNEATH MOVE TO FINALIZE AFTER REBOOT
# Enable snapshots with snapper
yaourtpkg snapper acl

echo -e "... >> Configure snapper"
snapper -c root create-config /
snapper -c home create-config /home

# we want the snaps located /at /mnt/btrfs-root/_snaptshot rather than at the root
btrfs subvolume delete /.snapshots
btrfs subvolume delete /home/.snapshots

btrfs subvolume create /mnt/btrfs-arch/@snapshots/@root_snaps
btrfs subvolume create /mnt/btrfs-arch/@snapshots/@home_snaps

# # mount subvolume to original snapper subvolume
mkdir /.snapshots
mkdir /home/.snapshots
mount -o compress=lzo,subvol=@snapshots/@root_snaps /dev/mapper/arch /.snapshots
mount -o compress=lzo,subvol=@snapshots/@home_snaps /dev/mapper/arch /home/.snapshots

echo "# Snapper subvolume" >> /etc/fstab # add snapper subvolume to fstab
echo "LABEL=arch /.snapshots btrfs rw,noatime,ssd,discard,compress=lzo,space_cache,subvol=@snapshots/@root_snaps   0 0" >> /etc/fstab
echo "LABEL=arch /home/.snapshots  btrfs rw,noatime,ssd,discardcompress=lzo,space_cache,subvol=@snapshots/@home_snaps   0 0" >> /etc/fstab

sed -i "s/ALLOW_USERS=\"/ALLOW_USERS=\"$USER/g" /etc/snapper/configs/home # Allow $USER to modify the files
sed -i "s/ALLOW_USERS=\"/ALLOW_USERS=\"$USER/g" /etc/snapper/configs/root
sed 's/PRUNENAMES = "/PRUNENAMES = ".snapshots /g' -i /etc/updatedb.conf # do not index snapshot via mlocate
systemctl start snapper-timeline.timer snapper-cleanup.timer  # start and enable snapper
systemctl enable snapper-timeline.timer snapper-cleanup.timer

# change snapper timer to every 5 minutes
sed  "s|OnCalendar=hourly|OnCalendar=*:0\/5|g" -i /usr/lib/systemd/system/snapper-timeline.timer
sed  "s|OnUnitActiveSec=1d|OnUnitActiveSec=1h|g" -i /usr/lib/systemd/system/snapper-cleanup.timer

# change snap config for home directory
# sed  "s|TIMELINE_MIN_AGE=\"1800\"|TIMELINE_MIN_AGE=\"172800\"|g" -i /etc/snapper/configs/home      # keep all backup for 2 days (172800 seconds)
# sed  "s|TIMELINE_LIMIT_HOURLY=\"10\"|TIMELINE_LIMIT_HOURLY=\"96\"|g" -i /etc/snapper/configs/home  # keep daily backup fro 14 days (336 backup)
# sed  "s|TIMELINE_LIMIT_DAILY=\"10\"|TIMELINE_LIMIT_DAILY=\"14\"|g" -i /etc/snapper/configs/home    # keep daily backup for 14 days
# sed  "s|TIMELINE_LIMIT_WEEKLY=\"0\"|TIMELINE_LIMIT_WEEKLY=\"0\"|g" -i /etc/snapper/configs/home    # do not keep weekly backup
# sed  "s|TIMELINE_LIMIT_MONTHLY=\"10\"|TIMELINE_LIMIT_MONTHLY=\"24\"|g" -i /etc/snapper/configs/home # keep daily backup for 2 years (24)
# sed  "s|TIMELINE_LIMIT_YEARLY=\"10\"|TIMELINE_LIMIT_YEARLY=\"10\"|g" -i /etc/snapper/configs/home   # keep yearly backup for 10 years

setfacl -Rm "u:megavolts:rw" /etc/snapper/configs
setfacl -Rdm "u:megavolts:rw" /etc/snapper/configs

systemctl enable snapper-boot.timer

# Snapper before and after update
yaourtpkg snap-pac rsync

# Copy partition on kernel update to enable backup
echo /usr/share/libalpm/hooks/50_bootbackup.hook << EOF  
[Trigger]
Operation = Upgrade
Operation = Install
Operation = Remove
Type = Package 
Target = linux* 
[Action] 
Depends = rsync 
Description = Backing up /boot... 
When = PreTransaction 
Exec = /usr/bin/rsync -a --delete /boot /.bootbackup
EOF


exit
