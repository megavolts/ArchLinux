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

#### kio-extras kio-fuse poppler-data kaccounts-integration


echo -e "Install software"
echo -e ".. basic tools"
yaourtpkg 'yakuake tmux kdialog kfind arp-scan htop kgpg '

echo -e ".. partition tools"
yaourtpkg 'gparted ntfs-3g exfat-utils mtools'

# echo -e "... installing fonts"
yaourtpkg 'ttf-dejavu ttf-mathtype freefonts ttf-inconsolata ttf-hack ttf-anonymous-pro ttf-liberation'


# echo -e ".. internet software"
yaourtpkg 'firefox thunderbird filezilla  nextcloud-client zoom teams slack-desktop telegram-desktop'

# Power management (https://austingwalters.com/increasing-battery-life-on-an-arch-linux-laptop-thinkpad-t14s/)
yaourtpkg 'tlp bash-completion smartmontools'
# if linux : acpi_call tp_smapi
systemctl start tlp.service
systemctl enable tlp.service

# echo -e ".. coding tools"
yaourtpkg 'sublime-text-dev'

# echo -e ".. media"
yaourtpkg 'dolphin dolphin-plugins qt5-imageformats ffmpegthumbs lzop kdegraphics-thumbnailers kimageformats libappimage unrar unzip'
yaourtpkg 'openconnect networkmanager-openconnect'

yaourtpkg 'ark unrar p7zip unzip'

# echo -e "... viewer"
yaourtpkg 'okular spectacle discount kdegraphics-mobipocket'

# echo -e "... images"
yaourtpkg 'imagemagick guetzli geeqie inkscape gimp darktable libraw hugin-hg'

# echo -e "... musics and videos"
yaourtpkg 'vlc ffmpeg jellyfin jellyfin-media-player jellyfin-server'

# echo -e ".. office"
yaourtpkg 'libreoffice-fresh mendeleydesktop texmaker texlive-most'
yaourtpkg 'aspell-fr aspell-en aspell-de hunspell-en_US hunspell-fr hunspell-de hyphen-en hyphen-en hyphen-de libmythes mythes-en mythes-fr libreoffice-extension-grammalecte-fr'

# echo -e ".. printing tools"
yaourtpkg 'cups system-config-printer'

yaourtpkg 'virtualbox virtualbox-guest-iso virtualbox-host-dkms virtualbox-ext-oracle'
groupadd vboxusers
gpasswd -a megavolts vboxusers
echo "vboxdrv vboxnetadp vboxnetflt" >> /usr/lib/modules-load.d/virtualbox-host-dkms.conf    

# # python packages
yaourtpkg 'pycharm-professional-edition python-pip python-setuptools'
yaourtpkg 'python-numpy python-matplotlib python-scipy python-pandas python-openpyxl python-basemap'
yaourtpkg 'python-numpy python-matplotlib python-scipy python-pandas python-openpyxl ipython jupyter cython'

# # citation
yaourtpkg 'mendeleydesktop zotero'

# yaourtpkg 'packages
yaourtpkg packages
echo -e "... don't forget to install Antidote"

yaourtpkg 'xdg-desktop-portal xdg-desktop-portal-kde'
yaourtpkg 'qownnotes'

yaourtpkg ' profile-sync-daemon'
echo -e "... configure profile-sync-daemon to improve speed, reduced wear to physical drives"
echo "megavolts ALL=(ALL) NOPASSWD: /usr/bin/psd-overlay-helper" >> /etc/sudoers
mkdir /home/megavolts/.config/psd/
wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/config/psd.conf -O /home/megavolts/.config/psd/psd.conf
systemctl --user start psd

exit
