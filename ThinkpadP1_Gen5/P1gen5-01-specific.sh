# #/bin/bash!
# ssh megavolts@IP
# install graphic consol
PASSWORD=$1
NEWUSER=$2
HOSTNAME=$3

echo -e ".. > Optimize mirrorlist"
pacman -S --noconfirm reflector"
systemctl enable --now reflector.timer
sed -i "s|# --country France,Germany|--country USA,Switzerland|g" /etc/xdg/reflector/reflector.conf

echo -e ".. install basic console tools"
pacman -S --noconfirm mlocate acl util-linux fwupd arp-scan htop lsof strace screen

# update database
updatedb

# fix access for user megavolts to /opt
setfacl -Rm "u:${NEWUSER}:rwx" /opt
setfacl -Rdm "u:${NEWUSER}:rwx" /opt
setfacl -Rm "u:${NEWUSER}:rwx" /mnt/data
setfacl -Rdm "u:${NEWUSER}:rwx" /mnt/data

# enable fstrim for ssd
systemctl enable --now fstrim.timer

## Graphical interface
echo -e "Graphic interface"
echo -e ".. Install drivers specific to Intel Corporation Alder Lake-P Integrated Graphics Controller"
pacman -S --noconfirm mesa vulkan-intel vulkan-mesa-layers
# Enable GuC/HuC firmware loading
echo "options i915 enable_guc=2" >> /etc/modprobe.d/i915.conf
mkinitcpio -p linux-zen 

echo -e ".. Install xorg and input"
pacman -S --noconfirm xorg-server xorg-apps xorg-xinit xorg-xrandr xorg-xkill xorg-xauth

echo -e "... install plasma windows manager"
pacman -S --noconfirm plasma-desktop sddm plasma-nm kscreen powerdevil plasma-wayland-session plasma-pa plasma-thunderbolt jack2 ttf-droid wireplumber phonon-qt5-gstreamer 

echo -e ".. install audio server"
pacman -S --noconfirm pipewire lib32-pipewire pipewire-docs pipewire-alsa lib32-pipewire-jack qpwgraph

echo -e ".. Installing bluetooth"
pacman -S --noconfirm bluez bluez-utils bluedevil
systemctl enable --now bluetooth

echo -e ".. Installing graphic tools"
pacman -S --noconfirm yakuake kdialog kfind kdeconnect barrier wl-clipboard kwallet-pam sddm-kcm xdg-desktop-portal-kde

echo -e "Install software"
echo -e ".. partition tools"
yay -S --noconfirm gparted ntfs-3g exfat-utils mtools sshfs bindfs

echo -e "... network tools"
yay -S --noconfirm dnsmasq nm-connection-editor openconnect networkmanager-openconnect

echo -e "... android tools"
yay -S --noconfirm android-tools android-udev  

echo -e "... installing fonts"
yay -S --noconfirm  freefonts ttf-inconsolata ttf-hanazono ttf-hack ttf-anonymous-pro ttf-liberation gnu-free-fonts noto-fonts ttf-bitstream-vera ttf-croscore ttf-dejavu ttf-droid ttf-ibm-plex

echo -e ".. internet software"
yay -S --noconfirm firefox thunderbird filezilla zoom teams slack-wayland telegram-desktop signal-desktop profile-sync-daemon vdhcoapp-bin
yay -S --noconfirm pass-git protonmail-bridge-bin protonvpn-gui qtpass secret-service

# echo -e ".. media"
yay -S --noconfirm dolphin dolphin-plugins qt5-imageformats ffmpegthumbs lzop kdegraphics-thumbnailers kimageformats raw-thumbnailer kio-gdrive libappimage
yay -S --noconfirm ark unrar p7zip zip

echo -e ".. sync software"
yay -S --noconfirm c++utilities 
yay -S --noconfirm qtutilities 
yay -S --noconfirm qtforkawesome 
yay -S --noconfirm syncthingtray syncthing nextcloud-client

echo -e ".. coding tools"
yay -S --noconfirm sublime-text-4 terminator zettlr pycharm-professional python-pip python-setuptools tk python-utils

echo -e ".. python pagckages"
yay -S --noconfirm python-utils python-numpy python-matplotlib python-scipy python-pandas python-openpyxl python-basemap python-pillow cython jupyterlab jupyter-notebook ipython 

echo -e "... viewer"
yay -S --noconfirm okular spectacle discount kdegraphics-mobipocket 

echo -e "... images"
yay -S --noconfirm imagemagick guetzli geeqie inkscape gimp darktable libraw hugin digikam kipi-plugins

echo -e "... musics and videos"
yay -S --noconfirm vlc ffmpeg jellyfin-bin jellyfin-media-player picard picard-plugins-git

echo -e ".. office"
yay -S --noconfirm libreoffice-fresh mendeleydesktop texmaker texlive-most zotero
yay -S --noconfirm aspell-fr aspell-en aspell-de hunspell-en_US hunspell-fr hunspell-de hyphen-en hyphen-en hyphen-de libmythes mythes-en mythes-fr libreoffice-extension-grammalecte-fr

# echo -e ".. confing tools"
yay -S --noconfirm kinfocenter kruler sonnet-git discover packagekit-qt5 

# echo -e ".. printing tools"
yay -S --noconfirm cups system-config-printer
systemctl enable --now cups.service


# echo -e ".. virtualization tools"
yay -S --noconfirm virtualbox virtualbox-guest-iso virtualbox-host-dkms virtualbox-ext-oracle
# # For cursor in wayland session
# echo "KWIN_FORCE_SW_CURSOR=1" >> /etc/environement


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


echo -e "... create yay subvolume for megavolts"
sudo rm -R /home/$USER/.cache/yay
sudo btrfs subvolume create /mnt/btrfs/data/@$USER
sudo btrfs subvolume create /mnt/btrfs/data/@$USER/@cache_yay
sudo btrfs subvolume create /mnt/btrfs/data/@$USER/@download


echo -e "... configure megavolts user directory"
sudo cat <<EOF | sudo tee -a /etc/fstab > /dev/null
## USER: megavolts
# yay cache
/dev/mapper/data  /home/$USER/.cache/yay  btrfs rw,nodev,noatime,nocow,compress=zstd:3,ssd,discard,space_cache=v2,subvol=/@$USER/@cache_yay 0 0

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

# FOR USER
systemctl enable --user --now pipewire
systemctl enable --user --now pipewire-pulse



# IF ISSUE CHECK TO INSTALL
sddm-git



echo "KWallet login"
echo "auth            optional        pam_kwallet5.so" >> /etc/pam.d/sddm
echo "session         optional        pam_kwallet5.so auto_start" >> /etc/pam.d/sddm


# IF pass git is required, install pass-git
sudo -u megavolts yay -S --noconfirm pass-git


# FIX user permssion in folder
find ~ \! -uid `id -u` -o \! -gid `id -g`