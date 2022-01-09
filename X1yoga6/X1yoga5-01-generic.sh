
#/bin/bash!
# ssh megavolts@IP

PWD=$1

echo -e "Install software"
echo -e ".. basic tools"
yay -S --noconfirm yakuake kdialog kfind arp-scan htop kdeconnect barrier lsof strace
# guake or tilda

echo -e ".. partition tools"
yay -S --noconfirm gparted ntfs-3g exfat-utils mtools sshfs

# echo -e "... installing fonts"
yay -S --noconfirm  ttf-dejavu freefonts ttf-inconsolata ttf-hack ttf-anonymous-pro ttf-liberation

# echo -e ".. internet software"
yay -S --noconfirm firefox thunderbird filezilla  nextcloud-client zoom teams slack-wayland telegram-desktop

yay -S --noconfirm dolphin ffpmegthumbs kdegraphics-thumbnailers konsole purpose   

# echo -e ".. coding tools"
yay -S --noconfirm sublime-text-dev

# echo -e ".. media"
yay -S --noconfirm dolphin dolphin-plugins qt5-imageformats ffmpegthumbs lzop kdegraphics-thumbnailers kimageformats libappimage unrar unzip
yay -S --noconfirm openconnect networkmanager-openconnect
yay -S --noconfirm ark unrar p7zip unzip

# echo -e "... viewer"
yay -S --noconfirm okular spectacle discount kdegraphics-mobipocket

# echo -e "... images"
yay -S --noconfirm imagemagick guetzli geeqie inkscape gimp darktable libraw hugin-hg

# echo -e "... musics and videos"
yay -S --noconfirm vlc ffmpeg jellyfin jellyfin-media-player jellyfin-server

# echo -e ".. office"
yay -S --noconfirm libreoffice-fresh mendeleydesktop texmaker texlive-most
yay -S --noconfirm aspell-fr aspell-en aspell-de hunspell-en_US hunspell-fr hunspell-de hyphen-en hyphen-en hyphen-de libmythes mythes-en mythes-fr libreoffice-extension-grammalecte-fr

# echo -e ".. printing tools"
yay -S --noconfirm cups system-config-printer

yay -S --noconfirm virtualbox virtualbox-guest-iso virtualbox-host-dkms virtualbox-ext-oracle
groupadd vboxusers
gpasswd -a megavolts vboxusers
echo "vboxdrv vboxnetadp vboxnetflt" >> /usr/lib/modules-load.d/virtualbox-host-dkms.conf    

# # python packages
yay -S --noconfirm pycharm-professional python-pip python-setuptools tk python-utils
pip install numpy matplotlib scipy pandas openpyxl basemap pillow cython jupyter ipython 

# citation
yay -S --noconfirm mendeleydesktop zotero

echo -e "... don't forget to install Antidote"

# yaourtpkg 'xdg-desktop-portal xdg-desktop-portal-kde'
yaourtpkg 'qownnotes'

yay -S --noconfirm profile-sync-daemon
echo -e "... configure profile-sync-daemon to improve speed, reduced wear to physical drives"
echo "megavolts ALL=(ALL) NOPASSWD: /usr/bin/psd-overlay-helper" >> /etc/sudoers
mkdir /home/megavolts/.config/psd/
wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/config/psd.conf -O /home/megavolts/.config/psd/psd.conf
systemctl --user start psd

# autorotate
yay -S --noconfirm iio-sensor-proxy maliit-keyboard

castnow cast_control

exit
