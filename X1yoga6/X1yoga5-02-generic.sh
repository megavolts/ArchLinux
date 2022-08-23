
#/bin/bash!
# ssh megavolts@IP

# Disable COW for thunderbird and baloo
mkdir /home/$USER/.thunderbird
chattr +C /home/$USER/.thunderbird
mkdir /home/$USER/.local/share/baloo/
chattr +C /home/$USER/.local/share/baloo/

PWD=$1

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
yay -S --noconfirm firefox thunderbird filezilla  nextcloud-client zoom teams slack-wayland telegram-desktop signal-desktop firefox-kde-opensuse


# echo -e ".. coding tools"
yay -S --noconfirm sublime-text-4 terminator

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

# echo -e ".. confing tools"
yay -S --noconfirm rysnc kinfocenter kruler sonnet fwupd discover packagekit-qt5

yay -S --noconfirm virtualbox virtualbox-guest-iso virtualbox-host-dkms virtualbox-ext-oracle
groupadd vboxusers
gpasswd -a megavolts vboxusers
#echo "vboxdrv vboxnetadp vboxnetflt" >> /usr/lib/modules-load.d/virtualbox-host-dkms.conf    
# For cursor in wayland session
echo "KWIN_FORCE_SW_CURSOR=1" >> /etc/environement


# # python packages
yay -S --noconfirm pycharm-professional python-pip python-setuptools tk python-utils
yay -S --noconfirm python-numpy python-matplotlib python-scipy python-pandas python-openpyxl python-basemap python-pillow cython jupyter ipython 

echo -e "... don't forget to install Antidote"

yay -S --noconfirm vdhcoapp-bin

# yaourtpkg 'xdg-desktop-portal xdg-desktop-portal-kde'
# yaourtpkg 'qownnotes'

yay -S --noconfirm profile-sync-daemon
echo -e "... configure profile-sync-daemon to improve speed, reduced wear to physical drives"
echo "megavolts ALL=(ALL) NOPASSWD: /usr/bin/psd-overlay-helper" >> /etc/sudoers
mkdir /home/megavolts/.config/psd/
wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/config/psd.conf -O /home/megavolts/.config/psd/psd.conf
systemctl enable --now --user psd

# castnow cast_control mkchromecast

yay -S --noconfirm protonmail-bridge-bin protonvpn-gui pass-git qtpass secret-service
systemctl enable --now --user secretserviced.service 
sed -i '1s/^/"user_ssl_smtp": "false"/' .config/protonmail/bridge/prefs.json
gpg --batch --passphrase '' --quick-gen-key 'ProtonMail Bridge' default default never
pass init "ProtonMail Bridge"
protonmail-bridge --cli

exit
