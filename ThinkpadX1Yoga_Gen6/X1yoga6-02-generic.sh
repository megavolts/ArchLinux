
#/bin/bash!
# ssh megavolts@IP

# Disable COW for thunderbird and baloo
mkdir -p /home/$USER/.thunderbird
chattr +C /home/$USER/.thunderbird
mkdir -p /home/$USER/.local/share/baloo/
chattr +C /home/$USER/.local/share/baloo/
mkdir -p /home/$USER/.config/protonmail/bridge/cache 
chattr +C /home/$USER/.config/protonmail/bridge/cache
mkdir -p /home/$USER/.cache/yay
chattr +C /home/$USER/.cache/yay

echo -e "Install software"
echo -e ".. Installing utiilty"
yay -S --noconfirm yakuake kdialog kfind arp-scan htop kdeconnect barrier lsof strace wl-clipboard pass-git sddm-kcm xdg-desktop-portal-kde kvantum kwallet-pam
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
yay -S --noconfirm firefox thunderbird filezilla zoom teams telegram-desktop signal-desktop protonmail-bridge-bin protonvpn-gui 

# echo -e ".. coding tools"
yay -S --noconfirm sublime-text-4 terminator zettlr screen

# echo -e ".. media"
yay -S --noconfirm dolphin dolphin-plugins ffmpegthumbs lzop kdegraphics-thumbnailers libappimage kio-gdrive qt5-imageformats ark unrar p7zip unzip kimageformats5 kdegraphics-mobipocket
yay -S --noconfirm raw-thumbnailer 

# echo -e "... viewer"
yay -S --noconfirm okular spectacle discount 

# echo -e "... images"
yay -S --noconfirm imagemagick guetzli geeqie inkscape gimp darktable libraw hugin digikam

# echo -e "... musics and videos"
yay -S --noconfirm vlc ffmpeg picard vdhcoapp-bin
yay -S --noconfirm jellyfin jellyfin-media-player picard-plugins-git
sudo sysetmctl enable --now jellyfin.service

# echo -e ".. office"
yay -S --noconfirm libreoffice-fresh mendeleydesktop texmaker texlive-most zotero
yay -S --noconfirm aspell-fr aspell-en aspell-de hunspell-en_US hunspell-fr hunspell-de hyphen-en hyphen-en hyphen-de libmythes mythes-en mythes-fr libreoffice-extension-grammalecte-fr

# echo -e ".. printing tools"
yay -S --noconfirm cups system-config-printer
sudo systemctl enable --now cups.service

# echo -e ".. confing tools"
yay -S --noconfirm rsync kinfocenter fwupd discover packagekit-qt5 kruler
yay -S --noconfirm c++utilities qtutilities qtforkawesome syncthing syncthingtray nextcloud-client
systemctl --user --now enable syncthing
systemctl --user --now enable ssh-agent

yay -S --noconfirm virtualbox virtualbox-guest-iso virtualbox-host-dkms virtualbox-ext-oracle
sudo groupadd vboxusers
sudo gpasswd -a megavolts vboxusers
# Check if needed
# #echo "vboxdrv vboxnetadp vboxnetflt" >> /usr/lib/modules-load.d/virtualbox-host-dkms.conf    
# # For cursor in wayland session
# sudo echo "KWIN_FORCE_SW_CURSOR=1" >> /etc/environement


# # python packages
yay -S --noconfirm pycharm-professional python-pip python-setuptools tk python-utils
yay -S --noconfirm python-numpy python-matplotlib python-scipy python-pandas python-openpyxl python-basemap python-pillow cython jupyterlab jupyter-notebook ipython 

echo -e "... don't forget to install Antidote"


echo -e "... enable 2 fingers scroll for mozilla firefox"
mkdir -p /home/$NEWUSER/.config/environment.d/
echo "PATH='$PATH:$HOME/scripts'" >> /home/$NEWUSER/.config/environment.d/envvars.conf
echo "GUIVAR=value" >> /home/$NEWUSER/.config/environment.d/envvars.conf
echo "MOZ_ENABLE_WAYLAND=1" >> /home/$NEWUSER/.config/environment.d/envvars.conf


exit
