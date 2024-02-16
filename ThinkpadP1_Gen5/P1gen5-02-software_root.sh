# #/bin/bash!
# ssh megavolts@IP
# install graphic consol# #/bin/bash!
# ssh megavolts@IP
# install graphic consol
PASSWORD=$1
USR=$2
HOSTNAME=$3
yays(){sudo -u $USR yay -S --removemake --cleanafter --noconfirm $1}

echo -e ".. Install xorg and input"
yays xorg-server xorg-apps xorg-xinit xorg-xrandr xorg-xkill xorg-xauth

echo -e "... install plasma windows manager"
yays plasma-desktop sddm plasma-nm kscreen powerdevil plasma-wayland-session plasma-pa plasma-thunderbolt jack2 ttf-droid wireplumber phonon-qt5-gstreamer 

echo -e ".. install audio server"
yays pipewire lib32-pipewire pipewire-docs pipewire-alsa lib32-pipewire-jack qpwgraph

echo -e ".. Installing bluetooth"
yays bluez bluez-utils bluedevil
sudo systemctl enable --now bluetooth

echo -e ".. Installing graphic tools"
yays yakuake kdialog kfind kdeconnect barrier wl-clipboard kwallet-pam sddm-kcm xdg-desktop-portal-kde

echo -e "Install software"
echo -e ".. partition tools"
yays gparted ntfs-3g exfat-utils mtools sshfs bindfs

echo -e "... network tools"
yays dnsmasq nm-connection-editor openconnect networkmanager-openconnect

echo -e "... android tools"
yays android-tools android-udev  

echo -e "... installing fonts"
yays  freefonts ttf-inconsolata ttf-hanazono ttf-hack ttf-anonymous-pro ttf-liberation gnu-free-fonts noto-fonts ttf-bitstream-vera ttf-croscore ttf-dejavu ttf-droid ttf-ibm-plex

echo -e ".. internet software"
yays firefox thunderbird filezilla zoom teams slack-wayland telegram-desktop signal-desktop profile-sync-daemon vdhcoapp-bin
yays pass-git protonmail-bridge-bin protonvpn-gui qtpass secret-service

# echo -e ".. media"
yays dolphin dolphin-plugins qt5-imageformats ffmpegthumbs lzop kdegraphics-thumbnailers kimageformats raw-thumbnailer kio-gdrive libappimage
yays ark unrar p7zip zip

echo -e ".. sync software"
yays c++utilities 
yays qtutilities 
yays qtforkawesome 
yays syncthingtray syncthing nextcloud-client

echo -e ".. coding tools"
yays sublime-text-4 terminator zettlr pycharm-professional python-pip python-setuptools tk python-utils

echo -e ".. python pagckages"
yays python-utils python-numpy python-matplotlib python-scipy python-pandas python-openpyxl python-basemap python-pillow cython jupyterlab jupyter-notebook ipython 

echo -e "... viewer"
yays okular spectacle discount kdegraphics-mobipocket 

echo -e "... images"
yays imagemagick guetzli geeqie inkscape gimp darktable libraw hugin digikam kipi-plugins

echo -e "... musics and videos"
yays vlc ffmpeg jellyfin-bin jellyfin-media-player picard picard-plugins-git

echo -e ".. office"
yays libreoffice-fresh mendeleydesktop texmaker texlive-most zotero
yays aspell-fr aspell-en aspell-de hunspell-en_US hunspell-fr hunspell-de hyphen-en hyphen-en hyphen-de libmythes mythes-en mythes-fr libreoffice-extension-grammalecte-fr

# echo -e ".. confing tools"
yays kinfocenter kruler sonnet-git discover packagekit-qt5 

# echo -e ".. printing tools"
yays cups system-config-printer
systemctl enable --now cups.service

# echo -e ".. virtualization tools"
yays virtualbox virtualbox-guest-iso virtualbox-host-dkms virtualbox-ext-oracle
# # For cursor in wayland session
# echo "KWIN_FORCE_SW_CURSOR=1" >> /etc/environement


systemctl enable --now sddm


# # IF ISSUE CHECK TO INSTALL
# sddm-git
# echo "KWallet login"
# echo "auth            optional        pam_kwallet5.so" >> /etc/pam.d/sddm
# echo "session         optional        pam_kwallet5.so auto_start" >> /etc/pam.d/sddm


# # IF pass git is required, install pass-git
# sudo -u megavolts yays pass-git


# # FIX user permssion in folder
# find ~ \! -uid `id -u` -o \! -gid `id -g`
PASSWORD=$1
NEWUSER=$2
HOSTNAME=$3
yays(){sudo -u $USR yay -S --removemake --cleanafter --noconfirm $1}

echo -e ".. Install xorg and input"
yay -S --noconfirm xorg-server xorg-apps xorg-xinit xorg-xrandr xorg-xkill xorg-xauth

echo -e "... install plasma windows manager"
yay -S --noconfirm plasma-desktop sddm plasma-nm kscreen powerdevil plasma-wayland-session plasma-pa plasma-thunderbolt jack2 ttf-droid wireplumber phonon-qt5-gstreamer 

echo -e ".. install audio server"
yay -S --noconfirm pipewire lib32-pipewire pipewire-docs pipewire-alsa lib32-pipewire-jack qpwgraph

echo -e ".. Installing bluetooth"
yay -S --noconfirm bluez bluez-utils bluedevil
sudo systemctl enable --now bluetooth

echo -e ".. Installing graphic tools"
yay -S --noconfirm yakuake kdialog kfind kdeconnect barrier wl-clipboard kwallet-pam sddm-kcm xdg-desktop-portal-kde

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
sudo systemctl enable --now cups.service


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

systemctl enable --now sddm


# # IF ISSUE CHECK TO INSTALL
# sddm-git
# echo "KWallet login"
# echo "auth            optional        pam_kwallet5.so" >> /etc/pam.d/sddm
# echo "session         optional        pam_kwallet5.so auto_start" >> /etc/pam.d/sddm


# # IF pass git is required, install pass-git
# sudo -u megavolts yay -S --noconfirm pass-git


# # FIX user permssion in folder
# find ~ \! -uid `id -u` -o \! -gid `id -g`