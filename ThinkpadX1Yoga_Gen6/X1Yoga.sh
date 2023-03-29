# /bin/bash
# Dual boot with windows
# With 2 DISK
# /dev/nvme0n1p1  512.0MiB  EF00  EFI system partition
# /dev/nvme1n1p1    8300 Linux Filesystem on LVM
# /dev/nvme1n1p2 1.5TiB
#   1            2048         1050623   512.0 MiB   EF00  EFI system partition
#   2         1050624         1083391   16.0 MiB    0C01  Microsoft reserved ...
#   3         1083392       537954303   256.0 GiB   0700  Basic data partition
#   4       537954304       571508735   16.0 GiB    2700  Recovery
# IF NTFSDATA
#   5       571508736      5666551807   2.4 TiB     8300  cryptarch
#   5      5666551808      7814035455   1024.0 GiB  0700  ntfsdata
# ELSE 
#   6      571508736       7814035455   3.4 TiB     8300  cryptarch

DISK=/dev/nvme0n1
NEWUSER=megavolts
BOOTPART=1
ROOTPART=5
DATAPART=6
INSTALL=True
FORMATDATA=False
NTFSDATA=True


echo 'Enter a default passphrase use to encrypt the disk and serve as password for root and megavolts:'
stty -echo
read PASSWORD
stty echo


if $INSTALL
then
  if $NTFSDATA
  then
    sgdisk -n $ROOTPART:571508736:7814035455 -t $ROOTPART:8300 -c $ROOTPART:"cryptarch" $DISK
  else
    sgdisk -n $ROOTPART:571508736:5666551807 -t $ROOTPART:8300 -c $ROOTPART:"cryptarch" $DISK
    sgdisk -n $ROOTPART:5666551808:7814035455 -t $DATAPART:0700 -c $DATAPART:"ntfsdata" $DISK
  fi

  echo -e ".. wipe partition"
  # Wipe partition with zeros after creating an encrypted container with a random key
  cryptsetup open --type plain ${DISK}p$ROOTPART container --key-file /dev/urandom 
  dd if =/dev/zero of=/dev/mapper/container status=progress bs=1M
  cryptsetup close container
  echo -e ".. encrypting root partition"
  echo -en $PASSWORD | cryptsetup luksFormat /dev/disk/by-partlabel/cryptarch -q
  echo -en $PASSWORD | cryptsetup luksOpen /dev/disk/by-partlabel/cryptarch arch
  mkfs.btrfs --force --label arch /dev/mapper/arch
  if $NTFSDATA and $FORMATDATA
    mkfs.ntfs --quick --label ntfsdata /dev/${DISK}p$DATAPART
  fi
else
  echo -en $PASSWORD | cryptsetup luksOpen /dev/disk/by-partlabel/cryptarch arch
fi


echo -e ".. create subvolumes"
mount -o defaults,compress=lzo,noatime,nodev,ssd,discard /dev/mapper/arch /mnt/

## Updte to the latest btrfs (btrfs > 6.0)
pacman -S btrfs-tools

if $INSTALL
then
  btrfs subvolume create /mnt/@swap
else
  mv /mnt/@root /mnt/@root_old
  btrfs subvolume delete /mnt/{@tmp,@var_log,@var_tmp,@var_abs,var_cache_pacman_pkg}
fi

echo -e "... create new root, var and tmp subvolume"
btrfs subvolume create /mnt/@root
# arch wiki recommentd
btrfs subvolume create /mnt/@var_log
# to prevent slowdown
btrfs subvolume create /mnt/@tmp
btrfs subvolume create /mnt/@var_abs
btrfs subvolume create /mnt/@var_tmp
btrfs subvolume create /mnt/@var_cache_pacman_pkg

# mount with option nodatacow for @var_abs, @var_tmp, @var_log, @var_cache_pacman_pkg
umount /mnt

if $INSTALL
then
  btrfs subvolume create /mnt/@home
  btrfs subvolume create /mnt/@data
  btrfs subvolume create /mnt/@swap
  btrfs subvolume create /mnt/@snapshots
  btrfs subvolume create /mnt/@snapshots/@root_snaps	
  btrfs subvolume create /mnt/@snapshots/@home_snaps	
  btrfs subvolume create /mnt/@snapshots/@data_snaps  
fi
umount /mnt

# Mount arch subvolume
mount -o defaults,compress=zstd,noatime,nodev,ssd,discard,subvol=@root /dev/mapper/arch /mnt

# Mount arch volume
mkdir -p /mnt/mnt/btrfs/arch
mount -o defaults,compress=zstd,noatime,nodev,ssd,discard /dev/mapper/arch /mnt/mnt/btrfs/arch


# Create swapfile
btrfs filesystem mkswapfile --size=32G /mnt/mnt/btrfs/arch/@swap/swapfile
swapon /mnt/mnt/btrfs/arch/@swap/swapfile
# get resume offset:
RESUME_OFFSET=$(btrfs inspect-internal map-swapfile -r /swapfile)

# Mount data subvolume
mkdir -p /mnt/{home,boot,tmp,mnt/data,var/log,var/tmp,var/abs,var/cache/pacman/pkg}
mount -o defaults,compress=zstd,noatime,nodev,nodatacow,ssd,discard,subvol=@tmp /dev/mapper/arch /mnt/tmp
mount -o defaults,compress=zstd,noatime,nodev,nodatacow,ssd,discard,subvol=@var_abs /dev/mapper/arch /mnt/var/abs
mount -o defaults,compress=zstd,noatime,nodev,nodatacow,ssd,discard,subvol=@var_log /dev/mapper/arch /mnt/var/log
mount -o defaults,compress=zstd,noatime,nodev,nodatacow,ssd,discard,subvol=@var_tmp /dev/mapper/arch /mnt/var/tmp
mount -o defaults,compress=zstd,noatime,nodev,nodatacow,ssd,discard,subvol=@var_cache_pacman_pkg /dev/mapper/arch /mnt/var/cache/pacman/pkg
mount -o defaults,compress=zstd,noatime,nodev,ssd,discard,subvol=@home /dev/mapper/arch /mnt/home
mount -o defaults,compress=zstd,noatime,nodev,ssd,discard,subvol=@data /dev/mapper/arch /mnt/mnt/data

##
echo -e "prepare disk for installation"
mkdir /mnt/boot
mount /dev/nvme0n1p1 /mnt/boot

# Install Arch Linux
pacman -Sy
pacman -S archlinux-keyring
pacstrap /mnt base linux-zen linux-zen-headers base-devel openssh sudo ntp wget grml-zsh-config btrfs-progs networkmanager usbutils linux-firmware sof-firmware yajl mkinitcpio git go nano zsh terminus-font refind intel-ucode

echo -e "Create fstab"
genfstab -L -p /mnt >> /mnt/etc/fstab
#sed 's/\/mnt\/btrfs\/arch\/@swap\/swapfileswap/\/mnt\/btrfs\/arch\/@swap\/swapfileswap//g' /mnt/etc/fstab

echo -e " .. > allowing wheel group to sudo"
sed -i 's/^#\s*\(%wheel\s*ALL=(ALL)\s*ALL\)/\1/' /mnt/etc/sudoers

arch-chroot /mnt /bin/zsh

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

chsh -s $({)which zsh)

# create $USER

echo -e "Setting up users"
echo -e ".. > setting root password"
passwd root << EOF
$PASSWORD
$PASSWORD
EOF
echo -e ".. > create user $NEWUSER with default password"
groupadd vboxusers
useradd -m -g users -G wheel,audio,disk,lp,network,vboxusers -s /bin/zsh $NEWUSER
passwd $NEWUSER << EOF
$PASSWORD
$PASSWORD
EOF

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
  rm ./$1.tar.gz
}

buildpkg package-query
buildpkg yay

#wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/X220/source/mirrorupgrade.hook -P /etc/pacman.d/hooks/
echo -e "Configure system"
echo "FONT=ter-132n" >> /etc/vconsole.conf
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
echo "127.0.0.1    $HOSTNAME.localdomain    $HOSTNAME" >> /etc/hosts
echo $HOSTNAME > /etc/hostname

echo -e ".. > start services"
systemctl enable NetworkManager
systemctl enable sshd
systemctl enable btrfs-scrub@home.timer 
systemctl enable btrfs-scrub@-.timer 

# add btrfs hook and remove fsck
sed -i 's/fsck)/btrfs)/g' /etc/mkinitcpio.conf

# add encrypt and keyboard hook before filesystems
sed -i 's/udev/udev keyboard encrypt resume filesystems/g' /etc/mkinitcpio.conf

# modify refind.conf
if $INSTALL
then
  pacman -S refind
  refind-install
  cp /boot/refind_linux.conf /boot/refind_linux.conf.old
  wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/X1yoga6/sources/refind.conf -O /boot/refind_linux.conf
fi

# Rebuild kernel
if [ -f /boot/vmlinuz-linux ]; then
	mkinitcpio -p linux
fi
if [ -f /boot/vmlinuz-linux-zen ]; then
	mkinitcpio -p linux-zen
fi
exit

## Create /etc/
#dd if=/dev/urandom of=/dev/data.keyfile count=2048
#cryptsetup luksAddKey /dev/disk/by-partlabel/cryptdata /etc/data.keyfile
#echo "data  /dev/disk/by-partlabel/cryptdata /etc/data.keyfile"
#echo "data           /dev/disk/by-partlabel/cryptdata             /etc/data.keyfile" >> /etc/crypttab

umount /mnt/{boot,home,data}
reboot



#/bin/bash!
# ssh megavolts@IP

PASSWORD=$1
NEWUSER=$2
HOSTNAME=$3

echo -e ".. > Optimize mirrorlist"
yay -S --noconfirm reflector
reflector --latest 20 --protocol http --protocol https --sort rate --save /etc/pacman.d/mirrorlist

pacman -S --noconfirm mlocate
updatedb

# Enable snapshots with snapper 
yay -S --noconfirm snapper acl snapper-gui-git
echo -e "... >> Configure snapper"
snapper -c root create-config /

# we want the snaps located /at /mnt/btrfs-root/_snaptshot rather than at the root
btrfs subvolume delete /.snapshots

if [ -d "/home/.snapshots"]
then
  rmdir /home/.snapshots
fi
snapper -c home create-config /home
btrfs subvolume delete /home/.snapshots

mkdir /.snapshots
mkdir /home/.snapshots

mount -o compress=lzo,subvol=@snapshots/@root_snaps /dev/mapper/arch /.snapshots
mount -o compress=lzo,subvol=@snapshots/@home_snaps /dev/mapper/arch /home/.snapshots

# Add entry in fstab
# echo "# Snapper subvolume" >> /etc/fstab # add snapper subvolume to fstab
echo "/dev/mapper/arch /.snapshots btrfs rw,noatime,ssd,discard,compress=lzo,space_cache,subvol=@snapshots/@root_snaps   0 0" >> /etc/fstab
echo "/dev/mapper/arch /home/.snapshots  btrfs rw,noatime,ssd,discardcompress=lzo,space_cache,subvol=@snapshots/@home_snaps   0 0" >> /etc/fstab

# echo "# Snapper subvolume" >> /etc/fstab # add snapper subvolume to fstab
sed "s/ALLOW_USERS=\"/ALLOW_USERS=\"$NEWUSER/g" -i /etc/snapper/configs/home # Allow $NEWUSER to modify the files
sed "s/ALLOW_USERS=\"/ALLOW_USERS=\"$NEWUSER/g" -i /etc/snapper/configs/root
sed "s/ALLOW_GROUPS=\"/ALLOW_GROUPS=\"wheel/g" -i /etc/snapper/configs/home # Allow $NEWUSER to modify the files
sed "s/ALLOW_GROUPS=\"/ALLOW_GROUPS=\"wheel/g" -i /etc/snapper/configs/root

sed "s/SYNC_ACL=\"no/SYNC_ACL=\"yes/g" -i /etc/snapper/configs/root
sed "s/SYNC_ACL=\"no/SYNC_ACL=\"yes/g" -i /etc/snapper/configs/home

sed 's/PRUNENAMES = "/PRUNENAMES = ".snapshots /g' -i /etc/updatedb.conf # do not index snapshot via mlocate

systemctl start snapper-timeline.timer snapper-cleanup.timer  # start and enable snapper
systemctl enable snapper-timeline.timer snapper-cleanup.timer

# Execute cleanup everyhour:
SYSTEMD_EDITOR=tee systemctl edit snapper-cleanup.timer <<EOF
[Timer]
OnUnitActiveSec=1h
EOF

# Execute snapshot every 5 minutes:
SYSTEMD_EDITOR=tee systemctl edit snapper-timeline.timer <<EOF
[Timer]
OnCalendar=*:0\/5/
EOF

setfacl -Rm "u:megavolts:rwx" /etc/snapper/configs
setfacl -Rdm "u:megavolts:rwx" /etc/snapper/configs

# update snap config for home directory
sed  "s|TIMELINE_MIN_AGE=\"1800\"|TIMELINE_MIN_AGE=\"1800\"|g" -i /etc/snapper/configs/home      # keep all backup for 2 days (172800 seconds)
sed  "s|TIMELINE_LIMIT_HOURLY=\"10\"|TIMELINE_LIMIT_HOURLY=\"96\"|g" -i /etc/snapper/configs/home  # keep hourly backup for 96 hours
sed  "s|TIMELINE_LIMIT_DAILY=\"10\"|TIMELINE_LIMIT_DAILY=\"14\"|g" -i /etc/snapper/configs/home    # keep daily backup for 14 days
sed  "s|TIMELINE_LIMIT_WEEKLY=\"0\"|TIMELINE_LIMIT_WEEKLY=\"0\"|g" -i /etc/snapper/configs/home    # do not keep weekly backup
sed  "s|TIMELINE_LIMIT_MONTHLY=\"10\"|TIMELINE_LIMIT_MONTHLY=\"12\"|g" -i /etc/snapper/configs/home # keep monthly backup for 12 months
sed  "s|TIMELINE_LIMIT_YEARLY=\"10\"|TIMELINE_LIMIT_YEARLY=\"5\"|g" -i /etc/snapper/configs/home   # keep yearly backup for 10 years

# enable snapshot at boot
systemctl enable snapper-boot.timer

# Copy partition on kernel update to enable backup
echo /usr/share/libalpm/hooks/50_bootbackup.hook << EOF  
[Trigger]
Operation = Upgrade
Operation = Install
Operation = Remove
Type = Path
Target = usr/lib/modules/*/vmlinuz

[Action]
Depends = rsync
Description = Backing up /boot...
When = PostTransaction
Exec = /usr/bin/rsync -a --delete /boot /.bootbackup
EOF
mkdir /.bootbackup

# enable snapshot before and after install
yay -S --noconfirm snap-pac rsync


## Enable fstrim for ssd
pacman -S util-linux fwupd packagekit-qt5
systemctl enable fstrim.trimer --now 

## Graphical interface
echo -e ".. install drivers specific to X1 with Iris"
yay -S --noconfirm mesa vulkan-intel vulkan-mesa-layers

echo -e ".. Install xorg and input"
yay -S --noconfirm xorg-server xorg-apps xorg-xinit xorg-xrandr xorg-xkill xorg-xauth

echo -e "... install plasma windows manager"
yay -S --noconfirm plasma-desktop sddm-git plasma-nm kscreen powerdevil plasma-wayland-session plasma-pa plasma-thunderbolt jack2 ttf-droid wireplumber phonon-qt5-gstreamer 

echo -e ".. install audio server"
yay -S --noconfirm pipewire lib32-pipewire pipewire-docs qpwgraph pipewire-alsa

echo -e ".. Installing bluetooth"
yay -S --noconfirm bluez bluez-utils bluedevil
systemctl enable --now bluetooth

echo -e ".. Installing bluetooth"
yay -S --noconfirm yakuake kdialog kfind arp-scan htop kdeconnect barrier lsof strace wl-clipboard pass-git kwallet-pam sddm-kcm xdg-desktop-portal-kde

echo "KWallet login"
echo "auth            optional        pam_kwallet5.so" >> /etc/pam.d/sddm
echo "session         optional        pam_kwallet5.so auto_start" >> /etc/pam.d/sddm

echo -e "Install software"
echo -e ".. partition tools"
yay -S --noconfirm gparted ntfs-3g exfat-utils mtools sshfs bindfs

# echo -e "... tools for hotspot"
yay -S --noconfirm dnsmasq nm-connection-editor openconnect networkmanager-openconnect

# echo -e "... tools for android"
yay -S --noconfirm android-tools android-udev  

# echo -e "... installing fonts"
yay -S --noconfirm  freefonts ttf-inconsolata ttf-hanazono ttf-hack ttf-anonymous-pro ttf-liberation gnu-free-fonts noto-fonts ttf-bitstream-vera ttf-croscore ttf-dejavu ttf-droid ttf-ibm-plex

# echo -e ".. internet software"
yay -S --noconfirm firefox thunderbird filezilla   zoom teams slack-wayland telegram-desktop signal-desktop profile-sync-daemon

# echo -e ".. sync software"
yay -S --noconfirm c++utilities qtutilities qtforkawesome syncthing syncthingtray nextcloud-client

# echo -e ".. coding tools"
yay -S --noconfirm sublime-text-4 terminator zettlr

# echo -e ".. media"
yay -S --noconfirm dolphin dolphin-plugins qt5-imageformats ffmpegthumbs lzop kdegraphics-thumbnailers kimageformats libappimage raw-thumbnailer kio-gdrive

yay -S --noconfirm ark unrar p7zip unzip

# echo -e "... viewer"
yay -S --noconfirm okular spectacle discount kdegraphics-mobipocket

# echo -e "... images"
yay -S --noconfirm imagemagick guetzli geeqie inkscape gimp darktable libraw hugin digikam kipi-plugins

# echo -e "... musics and videos"
yay -S --noconfirm vlc ffmpeg jellyfin-bin jellyfin-media-player picard picard-plugins-git

if [ !  -e /mnt/btrfs/arch/@media ]
then
  btrfs subvolume create /mnt/btrfs/arch/@media 
fi
if [ !  -e /mnt/btrfs/arch/@photography ]
then
  btrfs subvolume create /mnt/btrfs/arch/@photography
fi
if [ !  -e /mnt/btrfs/arch/@UAF-data ]
then
  btrfs subvolume create /mnt/btrfs/arch/@UAF-data
fi
if [ !  -e /mnt/btrfs/arch/@yay_cache ]
then
  btrfs subvolume create /mnt/btrfs/arch/@yay_cache
fi
if [ !  -e /mnt/btrfs/arch/@download ]
then
  btrfs subvolume create /mnt/btrfs/arch/@download
fi

mkdir -p /mnt/data/{media,UAF-data,media/photography}
echo "/dev/mapper/arch  /mnt/data/media               btrfs rw,nodev,noatime,compress=lzo,ssd,discard,space_cache=v2,subvol=@media 0 0" >> /etc/fstab
echo "/dev/mapper/arch  /mnt/data/UAF-data            btrfs rw,nodev,noatime,compress=lzo,ssd,discard,space_cache=v2,subvol=@UAF-data  0 0" >> /etc/fstab
echo "/dev/mapper/arch  /mnt/data/media/photography   btrfs rw,nodev,noatime,compress=lzo,ssd,discard,space_cache=v2,subvol=@photography 0 0" >> /etc/fstab

systemctl daemon-reload
mount -a

setfacl -m u:${NEWUSER}:rwx -R /mnt/data/
setfacl -m u:${NEWUSER}:rwx -Rd /mnt/data/


#echo -e "... enable 2 fingers scroll for mozilla firefox"
#mkdir -p /home/$NEWUSER/.config/environment.d/
#echo "PATH='$PATH:$HOME/scripts'" >> /home/$NEWUSER/.config/environment.d/envvars.conf
#echo "GUIVAR=value" >> /home/$NEWUSER/.config/environment.d/envvars.conf
#echo "MOZ_ENABLE_WAYLAND=1" >> /home/$NEWUSER/.config/environment.d/envvars.conf

# echo -e ".. office"
yay -S --noconfirm libreoffice-fresh mendeleydesktop texmaker texlive-most zotero
yay -S --noconfirm aspell-fr aspell-en aspell-de hunspell-en_US hunspell-fr hunspell-de hyphen-en hyphen-en hyphen-de libmythes mythes-en mythes-fr libreoffice-extension-grammalecte-fr

# echo -e ".. printing tools"
yay -S --noconfirm cups system-config-printer
systemctl enable --now cups.service

# echo -e ".. confing tools"
yay -S --noconfirm rsync kinfocenter kruler sonnet fwupd discover packagekit-qt5

yay -S --noconfirm virtualbox virtualbox-guest-iso virtualbox-host-dkms virtualbox-ext-oracle
groupadd vboxusers

#echo "vboxdrv vboxnetadp vboxnetflt" >> /usr/lib/modules-load.d/virtualbox-host-dkms.conf    
# For cursor in wayland session
echo "KWIN_FORCE_SW_CURSOR=1" >> /etc/environement


# # python packages
yay -S --noconfirm pycharm-professional python-pip python-setuptools tk python-utils
yay -S --noconfirm python-numpy python-matplotlib python-scipy python-pandas python-openpyxl python-basemap python-pillow cython jupyterlab jupyter-notebook ipython 

echo -e "... don't forget to install Antidote"

yay -S --noconfirm vdhcoapp-bin

## USER (megavolts)
# For NEWUSER=megavolts
$NEWUSER=megavolts

# Create media directory
mkdir -p /home/$NEWUSER/Pictures/{photography,meme,wallpaper,graphisme}
mkdir -p /home/$NEWUSER/Videos/{tvseries,movies,videos}
rm -R /home/$NEWUSER/.cache/yay
mkdir -p /home/$NEWUSER/.cache/yay

cat <<EOF | tee -a /etc/fstab
# $NEWUSER directory
# Yay cache
/dev/mapper/arch  /home/megavolts/.cache/yay  btrfs rw,nodev,noatime,nocow,compress=lzo,ssd,discard,space_cache=v2,subvol=@cache_yay 0 0"

# Download
/dev/mapper/arch  /home/megavolts/Downloads btrfs rw,nodev,noatime,compress=lzo,ssd,discard,clear_cache,nospace_cache,subvol=@download,uid=1000,gid=984,umask=022 0 0

# Media overlay
/mnt/data/media/musics    /home/megavolts/Music       fuse.bindfs     perms=0755,mirror-only=megavolts 0 0
/mnt/data/media/photography /home/megavolts/Pictures/photography  fuse,bindfs perms=0755,mirror-only=megavolts 0 0
/mnt/data/media/wallpaper       /home/megavolts/Pictures/wallpaper      fuse,bindfs     perms=0755,mirror-only=megavolts 0 0
/mnt/data/media/meme            /home/megavolts/Pictures/meme   fuse,bindfs     perms=0755,mirror-only=megavolts 0 0
/mnt/data/media/graphisme       /home/megavolts/Pictures/graphisme      fuse,bindfs     perms=0755,mirror-only=megavolts 0 0
/mnt/data/media/tvseries  /home/megavolts/Videos/tvseries   fuse,bindfs     perms=0755,mirror-only=megavolts 0 0
/mnt/data/media/movies    /home/megavolts/Videos/movies   fuse,bindfs     perms=0755,mirror-only=megavolts 0 0
/mnt/data/media/videos    /home/megavolts/Videos/videos     fuse,bindfs     perms=0755,mirror-only=megavolts 0 0
EOF

systemctl daemon-reload
mount -a
setfacl -m u:$NEWUSER:rwx -R .cache/yay 
setfacl -m u:$NEWUSER:rwx -Rd .cache/yay

# Disable COW for thunderbird and baloo
mkdir /home/$NEWUSER/.thunderbird
chattr +C /home/$NEWUSER/.thunderbird
mkdir /home/$NEWUSER/.local/share/baloo/
chattr +C /home/$NEWUSER/.local/share/baloo/
mkdir -p /home/$NEWUSER/.config/protonmail/bridge/cache 
chattr +C /home/$NEWUSER/.config/protonmail/bridge/cache

echo -e "... configure profile-sync-daemon to improve speed, reduced wear to physical drives"

sudo cat <<EOF | sudo tee -a /etc/sudoers
# $NEWUSER user
$NEWUSER ALL=(ALL) NOPASSWD: /usr/bin/psd-overlay-helper
EOF

mkdir /home/megavolts/.config/psd/
wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/config/psd.conf -O /home/megavolts/.config/psd/psd.conf
systemctl enable --now --user psd


yay -S --noconfirm protonmail-bridge-bin protonvpn-gui pass-git qtpass secret-service
systemctl enable --now --user secretserviced.service 
sed -i '1s/^/"user_ssl_smtp": "false"/' .config/protonmail/bridge/prefs.json
gpg --batch --passphrase '' --quick-gen-key 'ProtonMail Bridge' default default never
pass init "ProtonMail Bridge"
protonmail-bridge --cli




