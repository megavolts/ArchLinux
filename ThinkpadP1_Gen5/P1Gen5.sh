# /bin/bash
# Dual boot with windows
# With 2 DISK
# Windows Disk
# /dev/nvme1n1
#  1            2048         1050623   512.0 MiB   EF00  EFI2
#  2         1050624       537921535   256.0 GiB   8300  CRYPTROOT
#  3       537921536      7814035455     3.4 TiB   8300  CRYPTDATA

DISK=/dev/nvme1n1
WINDISK=/dev/nvme0n1
NEWUSER=megavolts
BOOTPART=1
ROOTPART=2
DATAPART=3
INSTALL=True
WIPEDATA=True

echo 'Enter a default passphrase use to encrypt the disk and serve as password for root and megavolts:'
stty -echo
read PASSWORD
stty echo


if $INSTALL
then
  sgdisk -n $ROOTPART:1050624:537921535 -t $ROOTPART:8300 -c $ROOTPART:"CRYPTROOT" $DISK

  # echo -e ".. prepare boot partition"
  mkfs.fat -F32 ${DISK}${BOOTPART} -n EFI2

  echo -e ".. wipe partition"
  # Wipe partition with zeros after creating an encrypted container with a random key
  cryptsetup open --type plain ${DISK}p$BOOTPART container --key-file /dev/urandom 
  dd if =/dev/zero of=/dev/mapper/container status=progress bs=1M
  cryptsetup close container
  echo -e ".. encrypting root partition"
  echo -en $PASSWORD | cryptsetup luksFormat ${DISK}p${ROOTPART} -q
  echo -en $PASSWORD | cryptsetup luksOpen /dev/disk/by-partlabel/CRYPTROOT root
  mkfs.btrfs --force --label arch /dev/mapper/root
else
  echo -en $PASSWORD | cryptsetup luksOpen /dev/disk/by-partlabel/CRYPTROOT root
fi

if $WIPEDATA
  echo -e ".. encrypting root partition"
  echo -en $PASSWORD | cryptsetup luksFormat ${DISK}p${DATAPART} -q
  echo -en $PASSWORD | cryptsetup luksOpen /dev/disk/by-partlabel/DATAPART data
  mkfs.btrfs --force --label arch /dev/mapper/data
else
  echo -en $PASSWORD | cryptsetup luksOpen /dev/disk/by-partlabel/DATAPART data
fi

echo -e ".. create subvolume on root"
mount -o defaults,compress=zstd:3,noatime,nodev,ssd,discard /dev/mapper/root /mnt/

if $INSTALL
then
  btrfs subvolume create /mnt/@swap
else
  mv /mnt/@root /mnt/@root_old
  btrfs subvolume delete /mnt/{@tmp,@var_log,@var_tmp,@var_abs,@var_cache_pacman_pkg,@snapshot}
fi

echo -e "... create new root, var* and tmp subvolume"
btrfs subvolume create /mnt/@root
# arch wiki recommentd
btrfs subvolume create /mnt/@var_log
# to prevent slowdown
btrfs subvolume create /mnt/@tmp
btrfs subvolume create /mnt/@var_abs
btrfs subvolume create /mnt/@var_tmp
btrfs subvolume create /mnt/@var_cache_pacman_pkg

echo -e ".. create subvolume on home"
mkdir /mnt/data
mount -o defaults,compress=zstd:3,noatime,nodev,ssd,discard /dev/mapper/data /mnt/data
if $WIPEDATA
  btrfs subvolume create /mnt/data/@home
  btrfs subvolume create /mnt/data/@data
  btrfs subvolume create /mnt/data/@snapshots
  btrfs subvolume create /mnt/data/@snapshots/@root_snaps  
  btrfs subvolume create /mnt/data/@snapshots/@home_snaps  
  btrfs subvolume create /mnt/data/@snapshots/@data_snaps  
fi

umount /mnt{/data,/}
echo -e ".. mount subvolume for install"

# Mount root subvolume
mount -o defaults,compress=zstd:3,noatime,nodev,ssd,discard,space_cache=v2,subvol=@root /dev/mapper/root /mnt

# Mount root and data volume
mkdir -p /mnt/mnt/btrfs/{arch,data}
mount -o defaults,compress=zstd,noatime,nodev,ssd,discard,space_cache=v2 /dev/mapper/root /mnt/mnt/btrfs/arch
mount -o defaults,compress=zstd,noatime,nodev,ssd,discard,space_cache=v2 /dev/mapper/data /mnt/mnt/btrfs/data


# Create swapfile
btrfs filesystem mkswapfile --size=64G /mnt/mnt/btrfs/root/@swap/swapfile
swapon /mnt/mnt/btrfs/arch/@swap/swapfile
# get resume offset:
RESUME_OFFSET=$(btrfs inspect-internal map-swapfile -r /mnt/mnt/btrfs/root/@swap/swapfile)

mkdir -p /mnt/{boot,.boot,tmp,var/log,var/tmp,var/abs,var/cache/pacman/pkg,home,mnt/data}
mount ${WINDISK}p${BOOTPART} /mnt/boot
mount ${DISK}p${BOOTPART} /mnt/.boot
mount -o defaults,compress=zstd,noatime,nodev,nodatacow,ssd,discard,subvol=@tmp /dev/mapper/root /mnt/tmp
mount -o defaults,compress=zstd,noatime,nodev,nodatacow,ssd,discard,subvol=@var_log /dev/mapper/root /mnt/var/log
mount -o defaults,compress=zstd,noatime,nodev,nodatacow,ssd,discard,subvol=@var_tmp /dev/mapper/root /mnt/var/tmp
mount -o defaults,compress=zstd,noatime,nodev,nodatacow,ssd,discard,subvol=@var_abs /dev/mapper/root /mnt/var/abs
mount -o defaults,compress=zstd,noatime,nodev,nodatacow,ssd,discard,subvol=@var_cache_pacman_pkg /dev/mapper/root /mnt/var/cache/pacman/pkg
mount -o defaults,compress=zstd,noatime,nodev,ssd,discard,space_cache=v2,subvol=@home /dev/mapper/data /mnt/home
mount -o defaults,compress=zstd,noatime,nodev,ssd,discard,space_cache=v2,subvol=@data /dev/mapper/data /mnt/mnt/data

# Install Arch Linux
pacman -Sy
pacman -S --noconfirm archlinux-keyring
pacstrap /mnt base linux-zen linux-zen-headers base-devel openssh sudo ntp wget grml-zsh-config btrfs-progs networkmanager usbutils linux-firmware sof-firmware yajl mkinitcpio git go nano zsh terminus-font refind intel-ucode

echo -e "Create fstab"
genfstab -L -p /mnt >> /mnt/etc/fstab
sed 's/\/mnt\/swap/\/swap/g' /mnt/etc/fstab

echo -e " .. > allowing wheel group to sudo"
sed -i 's/# %wheel ALL=(ALL:ALL)/%wheel ALL=(ALL:ALL)/g' /mnt/etc/sudoers

arch-chroot /mnt /bin/zsh

echo -e "Tuning pacman"
echo -e ".. > Adding multilib"
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
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
chsg -s /bin/zsh

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
  rm /home/$NEWUSER/$1.tar.gz
  cd $CURRENT_dir
}

buildpkg package-query
buildpkg yay

echo -e ".. > reflector to select faster download mirror"
yay -S --noconfirm reflector
systemctl enable reflector.timer

echo -e "Configure system"
echo "FONT=ter-132n" >> /etc/vconsole.conf
echo -e ".. > changing locales"
wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/X220/source/locale.gen -O /etc/locale.gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
locale-gen

echo -e ".. > set timezone to America/Anchorage"
ln -sf /usr/share/zoneinfo/America/Anchorage /etc/localtime
hwclock --systohc

echo -e ".. > setting hostname & network manager"
echo "127.0.1.1    $HOSTNAME.localdomain    $HOSTNAME" >> /etc/hosts
echo $HOSTNAME > /etc/hostname

echo -e ".. > start services"
systemctl enable NetworkManager
systemctl enable sshd
systemctl enable btrfs-scrub@home.timer 
systemctl enable btrfs-scrub@-.timer 

echo -e ".. add crypttab"
dd if=/dev/urandom of=/etc/cryptfs.key bs=1024 count=1
chmod 600 /etc/cryptfs.key 
CRYPTUUID=$(cryptsetup luksDump /dev/disk/by-partlabel/CRYPTDATA | grep UUID | cut -f2- -d: | sed -e 's/^[ \t]*//')
echo "data   UUID=$CRYPTUUID  /etc/cryptfs.key" >> /etc/crypttab

# add btrfs hook and remove fsck
sed -i 's/fsck)/btrfs)/g' /etc/mkinitcpio.conf

# add encrypt and keyboard hook before filesystems
sed -i 's/udev autodetect/udev keyboard encrypt resume filesystems autodetect/g' /etc/mkinitcpio.conf
sed -i 's/kms keyboard keymap/kms keymap/g' /etc/mkinitcpio.conf
sed -i 's/block filesystems btrfs/block btrfs/g' /etc/mkinitcpio.conf

# Rebuild kernel
if [ -f /boot/vmlinuz-linux ]; then
  mkinitcpio -p linux
fi
if [ -f /boot/vmlinuz-linux-zen ]; then
  mkinitcpio -p linux-zen
fi

# modify refind.conf
if $INSTALL
then
  pacman -S refind
  refind-install --usedefault ${WINDISK}p${BOOTPART}
  #rsync /boot /.boot
  cp /boot/refind_linux.conf /boot/refind_linux.conf.old
  wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/X1yoga6/sources/refind.conf -O /boot/refind_linux.conf
fi

exit
umount /mnt/{boot,home,data}
reboot



#/bin/bash!
# ssh megavolts@IP

PASSWORD=$1
NEWUSER=$2
HOSTNAME=$3

pacman -S --noconfirm mlocate acl rsync
updatedb

## Enable fstrim for ssd
pacman -S util-linux fwupd
systemctl enable fstrim.timer --now 

pacman -S --noconfirm packagekit-qt5  

## Graphical interface
echo -e ".. install drivers specific to Intel Corporation Alder Lake-P Integrated Graphics Controller"
pacman -S --noconfirm mesa vulkan-intel vulkan-mesa-layers
# Enable GuC/HuC firmware loading
echo "options i915 enable_guc=2" >> /etc/modprobe.d/i915.conf
mkinitcpio -p linux-zen 

# echo -e ".. install drivers specific to NVIDIA"
# pacman -S --noconfirm nvidia-dkms lib32-nvidia-utils
# pacman -Rns xf86-video-nouveau
# # Blacklist nouveau
# echo "blacklist nouveau" >> /etc/modprobe.d/00-nouveau_blacklist.conf 

# echo -e ".. install hybrid switch (PRIME Offload)"
# pacman -S --noconfirm nvidia-prime

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
yay -S --noconfirm firefox thunderbird filezilla   zoom teams slack-wayland telegram-desktop signal-desktop profile-sync-daemon vdhcoapp-bin
yay -S --noconfirm protonmail-bridge-bin protonvpn-gui pass-git qtpass secret-service

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

# echo -e ".. office"
yay -S --noconfirm libreoffice-fresh mendeleydesktop texmaker texlive-most zotero
yay -S --noconfirm aspell-fr aspell-en aspell-de hunspell-en_US hunspell-fr hunspell-de hyphen-en hyphen-en hyphen-de libmythes mythes-en mythes-fr libreoffice-extension-grammalecte-fr

# echo -e ".. printing tools"
yay -S --noconfirm cups system-config-printer
systemctl enable --now cups.service

# echo -e ".. confing tools"
yay -S --noconfirm rsync kinfocenter kruler sonnet fwupd discover packagekit-qt5 screen

# echo -e ".. virtualization tools"
yay -S --noconfirm virtualbox virtualbox-guest-iso virtualbox-host-dkms virtualbox-ext-oracle
# # For cursor in wayland session
# echo "KWIN_FORCE_SW_CURSOR=1" >> /etc/environement

# python packages
yay -S --noconfirm pycharm-professional python-pip python-setuptools tk python-utils
yay -S --noconfirm python-numpy python-matplotlib python-scipy python-pandas python-openpyxl python-basemap python-pillow cython jupyterlab jupyter-notebook ipython 

echo -e "... don't forget to install Antidote"


# BTRFS data subvolume
if [ !  -e /mnt/btrfs/data/@media ]
then
  btrfs subvolume create /mnt/btrfs/data/@media 
fi
if [ !  -e /mnt/btrfs/data/@photography ]
then
  btrfs subvolume create /mnt/btrfs/data/@photography
fi
if [ !  -e /mnt/btrfs/data/@UAF-data ]
then
  btrfs subvolume create /mnt/btrfs/data/@UAF-data
fi

mkdir -p /mnt/data/{media,UAF-data}
mkdir -p /mnt/data/media/{photography,wallpaper,meme,graphisme,tvseries,movies,videos,musics}
echo "/dev/mapper/data  /mnt/data/media               btrfs rw,nodev,noatime,compress=zstd:3,ssd,discard,space_cache=v2,subvol=@media 0 0" >> /etc/fstab
echo "/dev/mapper/data  /mnt/data/UAF-data            btrfs rw,nodev,noatime,compress=zstd:3,ssd,discard,space_cache=v2,subvol=@UAF-data  0 0" >> /etc/fstab
echo "/dev/mapper/data  /mnt/data/media/photography   btrfs rw,nodev,noatime,compress=zstd:3,ssd,discard,space_cache=v2,subvol=@photography 0 0" >> /etc/fstab

systemctl daemon-reload
mount -a
setfacl -m u:${NEWUSER}:rwx -R /mnt/data/
setfacl -m u:${NEWUSER}:rwx -Rd /mnt/data/


echo "megavolts user directory"
rm -R /home/$USER/.cache/yay
su megavolts

# Create directory:
# Create media directory
mkdir -p /home/$USER/Pictures/{photography,meme,wallpaper,graphisme}
mkdir -p /home/$USER/Videos/{tvseries,movies,videos}
mkdir -p /home/$USER/Musics
mkdir -p /home/$USER/.thunderbird
mkdir -p /home/$USER/.local/share/baloo/
mkdir -p /home/$USER/.config/protonmail/bridge/cache 

# Disable COW for thunderbird, baloo, protonmail
chattr +C /home/$USER/.thunderbird
chattr +C /home/$USER/.local/share/baloo/
chattr +C /home/$USER/.cache/yay
chattr +C /home/$USER/.config/protonmail/

echo -e "... configure profile-sync-daemon to improve speed, reduced wear to physical drives"
echo "$USER ALL=(ALL) NOPASSWD: /usr/bin/psd-overlay-helper"  | sudo tee -a /etc/sudoers > /dev/null
mkdir /home/$USER/.config/psd/
wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/config/psd.conf -O /home/$USER/.config/psd/psd.conf
systemctl enable --now --user psd

echo -e "... create yay subvolume for megavolts"
sudo rm -R /home/$USER/.cache/yay
sudo btrfs subvolume create /mnt/btrfs/data/@$USER
sudo btrfs subvolume create /mnt/btrfs/data/@$USER/@cache_yay
sudo btrfs subvolume create /mnt/btrfs/data/@$USER/@download


echo -e "... configure megavolts user directory"
cat <<EOF | sudo tee -a /etc/fstab > /dev/null
## USER: megavolts
# yay cache
/dev/mapper/data  /home/$USER/.cache/yay  btrfs rw,nodev,noatime,nocow,compress=zstd:3,ssd,discard,space_cache=v2,subvol=/@$USER/@cache_yay 0 0"

# Download
/dev/mapper/data  /home/$USER/Downloads btrfs rw,nodev,noatime,compress=zstd:3,ssd,discard,clear_cache,nospace_cache,subvol=/@$USER/@download,uid=1000,gid=984,umask=022 0 0

# Media overlay
/mnt/data/media/musics      /home/$USER/Musics                fuse.bindfs     perms=0755,mirror-only=$USER 0 0
/mnt/data/media/photography /home/$USER/Pictures/photography  fuse,bindfs     perms=0755,mirror-only=$USER 0 0
/mnt/data/media/wallpaper   /home/$USER/Pictures/wallpaper    fuse,bindfs     perms=0755,mirror-only=$USER 0 0
/mnt/data/media/meme        /home/$USER/Pictures/meme         fuse,bindfs     perms=0755,mirror-only=$USER 0 0
/mnt/data/media/graphisme   /home/$USER/Pictures/graphisme    fuse,bindfs     perms=0755,mirror-only=$USER 0 0
/mnt/data/media/tvseries    /home/$USER/Videos/tvseries       fuse,bindfs     perms=0755,mirror-only=$USER 0 0
/mnt/data/media/movies      /home/$USER/Videos/movies         fuse,bindfs     perms=0755,mirror-only=$USER 0 0
/mnt/data/media/videos      /home/$USER/Videos/videos         fuse,bindfs     perms=0755,mirror-only=$USER 0 0
EOF

sudo systemctl daemon-reload && sudo mount -a

systemctl enable --now --user secretserviced.service 
sed -i '1s/^/"user_ssl_smtp": "false"/' .config/protonmail/bridge/prefs.json
gpg --batch --passphrase '' --quick-gen-key 'ProtonMail Bridge' default default never
pass init "ProtonMail Bridge"
protonmail-bridge --cli

## Configure SNAPPER

# Enable snapshots with snapper 
yay -S --noconfirm snapper snapper-gui-git snap-pac
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

mount -o compress=zstd:3,subvol=@snapshots/@root_snaps /dev/mapper/arch /.snapshots
mount -o compress=zstd:3,subvol=@snapshots/@home_snaps /dev/mapper/arch /home/.snapshots

# Add entry in fstab
# echo "# Snapper subvolume" >> /etc/fstab # add snapper subvolume to fstab
echo "LABEL=arch /.snapshots btrfs rw,noatime,ssd,discard,compress=zstd:3,space_cache,subvol=@snapshots/@root_snaps   0 0" >> /etc/fstab
echo "LABEL=arch /home/.snapshots  btrfs rw,noatime,ssd,discardcompress=zstd:3,space_cache,subvol=@snapshots/@home_snaps   0 0" >> /etc/fstab

# echo "# Snapper subvolume" >> /etc/fstab # add snapper subvolume to fstab
sed "s/ALLOW_USERS=\"/ALLOW_USERS=\"$NEWUSER/g" -i /etc/snapper/configs/home # Allow $NEWUSER to modify the files
sed "s/ALLOW_USERS=\"/ALLOW_USERS=\"$NEWUSER/g" -i /etc/snapper/configs/root
sed "s/ALLOW_GROUPS=\"/ALLOW_GROUPS=\"wheel/g" -i /etc/snapper/configs/home # Allow $NEWUSER to modify the files
sed "s/ALLOW_GROUPS=\"/ALLOW_GROUPS=\"wheel/g" -i /etc/snapper/configs/root

sed "s/SYNC_ACL=\"no/SYNC_ACL=\"yes/g" -i /etc/snapper/configs/root
sed "s/SYNC_ACL=\"no/SYNC_ACL=\"yes/g" -i /etc/snapper/configs/root

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

/etc/updatedb.conf
PRUNENAMES = ".snapshots"

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



