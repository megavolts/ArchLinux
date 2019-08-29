#!/bin/bash
# execute as root
# 2019-08-29
USER=$1
echo $USER
# sublime-text-dev

yaourtpkg() {
  sudo -u $USER bash -c "yaourt -Syu --noconfirm $1"
}

packages=''

echo -e "Install software"
echo -e ".. basic tools"
yaourtpkg 'yakuake tmux kdialog kfind arp-scan'

echo -e ".. partition tools"
yaourtpkg 'gparted ntfs-3g exfat-utils mtools'

# echo -e "... installing fonts"
yaourtpkg 'ttf-dejavu font-mathematica ttf-mathtype freefonts ttf-inconsolata ttf-hack ttf-anonymous-pro ttf-liberation'


# echo -e ".. internet software"
yaourtpkg 'firefox thunderbird filezilla  nextcloud-client'

systemctl --user enable psd

# echo -e ".. coding tools"
yaourtpkg 'sublime-text-dev'

# echo -e ".. media"
yaourtpkg 'dolphin dolphin-plugins qt5-imageformats ffmpegthumbs lzop kdegraphics-thumbnailers'
yaourtpkg 'openconnect networkmanager-openconnect'

yaourtpkg 'ark unrar p7zip unzip'

# echo -e "... viewer"
yaourtpkg 'okular spectacle discount kdegraphics-mobipocket'

# echo -e "... images"
yaourtpkg 'imagemagick guetzli geeqie inkscape gimp darktable libraw hugin-hg'

# echo -e "... musics and videos"
yaourtpkg 'vlc plex-media-server-plexpass plex-media-player ffmpeg'

# echo -e ".. office"
yaourtpkg 'libreoffice-fresh mendeleydesktop texmaker texlive-most'
yaourtpkg 'aspell-fr aspell-en aspell-de hunspell-en_US hunspell-fr hunspell-de hyphen-en hyphen-en hyphen-de libmythes mythes-en mythes-fr libreoffice-extension-grammalecte-fr'

# echo -e ".. printing tools"
yaourtpkg 'cups system-config-printer'

yaourtpkg 'virtualbox virtualbox-guest-iso virtualbox-host-dkms linux-zen-headers virtualbox-ext-oracle linux-zen-headers'


# # internet messenging
yaourtpkg 'telegram-desktop'

# # python packages
yaourtpkg 'pycharm-community-edition python-pip'
yaourtpkg 'python-numpy python-matplotlib python-scipy python-pandas python-openpyxl python-basemap'
yaourtpkg 'python-numpy python-matplotlib python-scipy python-pandas python-openpyxl ipython jupyter cython'

# # citation
yaourtpkg 'mendeleydesktop'

# yaourtpkg 'packages
yaourtpkg packages
echo -e "... don't forget to install Antidote"

# # # Plex Media Player
# # yaourtpkg '"synergy "
systemctl start plexmediaserver
systemctl enable plexmediaserver
echo -e "... to configure plex-media-server visit http://localhost:32400/web/"

groupadd vboxusers
gpasswd -a megavolts vboxusers
echo "vboxdrv vboxnetadp vboxnetflt" >> /usr/lib/modules-load.d/virtualbox-host-dkms.conf    



yaourtpkg 'snapper-gui-git'

yaourtpkg 'xdg-desktop-portal xdg-desktop-portal-kde'


yaourtpkg 'qownnotes profile-sync-daemon'
echo -e "... configure profile-sync-daemon to improve speed, reduced wear to physical drives"
echo "megavolts ALL=(ALL) NOPASSWD: /usr/bin/psd-overlay-helper" >> /etc/sudoers
mkdir /home/megavolts/.config/psd/
wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/config/psd.conf -O /home/megavolts/.config/psd/psd.conf
systemctl --user start psd

exit
