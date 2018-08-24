#!/bin/bash
# execute as root

if [[ $( grep builduser /etc/passwd) ]]; then
  # create a fake builduser
  useradd builduser -m # Create the builduser
  passwd -d builduser # Delete the buildusers password
  echo "builduser ALL=(ALL) ALL" >> /etc/sudoers
  USER_FLAG=0
fi

buildpkg(){
  CURRENT_DIR=$pwd
  wget https://aur.archlinux.org/cgit/aur.git/snapshot/$1.tar.gz
  tar -xvzf $1.tar.gz -C /home/builduser
  chown builduser:builduser /home/builduser/$1 -R
  cd /home/builduser/$1
  sudo -u builduser bash -c "makepkg -si --noconfirm"
  cd $CURRENT_dir 
  rm /home/builduser/$1 -R
  rm $1.tar.gz
}

yaourtpkg() {
  sudo -u builduser bash -c "yaourt -S --noconfirm $1"
}

echo -e "Install software"
echo -e ".. basic tools"
yaourtpkg "yakuake tmux kdialog kfind xorg-xkill arp-scan"

echo -e ".. partition tools"
yaourtpkg "gparted ntfs-3g exfat-utils mtools"

echo -e "... installing fonts"
yaourtpkg "ttf-dejavu font-mathematica ttf-mathtype ttf-vista-fonts ttf-freefont ttf-inconsolata ttf-hack ttf-anonymous-pro ttf-freefont ttf-liberation"

echo -e ".. internet software"
yaourtpkg "firefox thunderbird filezilla profile-sync-daemon"
yaourtpkg "nextcloud-client qownnotes"

echo -e "... configure profile-sync-daemon to improve speed, reduced wear to physical drives"
echo "megavolts ALL=(ALL) NOPASSWD: /usr/bin/psd-overlay-helper" >> /etc/sudoers
wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/config/psd.conf -O /home/megavolts/.config/psd/psd.conf
systemctl --user start psd

echo -e ".. coding tools"
yaourtpkg "sublime-text-dev pycharm-community-edition"

echo -e ".. media"
yaourtpkg "dolphin dolphin-plugins qt5-imageformats ffmpegthumbs"
yaourtpkg "ark unrar"

echo -e "... viewer"
yaourtpkg "okular spectacle discount kdegraphics-mobipocket"

echo -e "... images"
yaourtpkg "imagemagick guetzli geeqie inkscape gimp darktable libraw hugin-hg"
hugin hugin-hg panomatic

echo -e "... musics and videos"
yaourtpkg "vlc amarok plex-media-server-plexpass plex-media-player ffmpeg"
systemctl start plexmediaserver
systemctl enable plexmediaserver

echo -e ".. office"
yaourtpkg "libreoffice-fresh mendeleydesktop texmake texlive-most"
yaourtpkg "aspell-fr aspell-en aspell-de hunspell-en hunspell-fr hunspell-de hyphen-en hyphen-en hyphen-de libmythes mythes-en mythes-fr libreoffice-extension-grammalecte-fr"

echo -e ".. printing tools"
yaourtpkg "cups foomatic-db foomatic-db-engine foomatic-db-nonfree"

yaourtpkg "synergy"

yaourtpkg "virtualbox virtualbox-guest-iso virtualbox-host-dkms linux-zen-headers virtualbox-ext-oracle"
gpasswd -a megavolts vboxusers
echo "vboxdrv vboxnetadp vboxnetflt" >> /usr/lib/modules-load.d/virtualbox-host-dkms.conf    

echo -e "... to configure plex-media-server visit http://localhost:32400/web/"
echo -e "... don't forget to install Antidote"

packages = ''

# internet messenging
packages +=  'telegram-desktop'

yaourtpkg packages

if [[ USER_FLAG==0 ]]; then
  userdel builduser
  rm /home/builduser -R
  sed -i 's/builduser ALL=(ALL) ALL//' /etc/sudoers
fi
