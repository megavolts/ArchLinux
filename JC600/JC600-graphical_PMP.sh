!/bin/bash
# execute as root

# Cofnigure locale
echo "en_US.UTF-8" >> /etc/locale.gen 
locale-gen 
localectl set-locale LANG=en_US.UTF-8

if [[ $( grep builduser /etc/passwd) ]]; then
  # create a fake builduser
  useradd builduser -m # Create the builduser
  passwd -d builduser # Delete the buildusers password
  echo "builduser ALL=(ALL) ALL" >> /etc/sudoers
  USER_FLAG=0
fi

echo -e ".. Install xorg and input"
pacman -S --noconfirm xorg-server xorg-apps xorg-xinit xorg-xrandr <<EOF
all
1
EOF

echo -e "... install plasma windows manager"
pacman -S plasma-desktop sddm powerdevil kscreen plasma-pa pavucontrol --noconfirm

echo -e "... configure sddm"
pacman -S sddm --noconfirm
sddm --example-config > /etc/sddm.conf
sed -i 's/Current=/Current=breeze/' /etc/sddm.conf
sed -i 's/CursorTheme=/CursorTheme=breeze_cursors/' /etc/sddm.conf
systemctl enable sddm

# Function
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
yaourtpkg "ttf-dejavu ttf-freefont "

echo -e ".. internet software"
yaourtpkg "firefox"

echo -e ".. coding tools"
yaourtpkg "sublime-text-dev"

echo -e ".. media"
yaourtpkg "dolphin dolphin-plugins qt5-imageformats ffmpegthumbs"
yaourtpkg "ark unrar p7zip unzip"

echo -e "... viewer"
yaourtpkg "okular spectacle discount kdegraphics-mobipocket"

yaourtpkg "networkmanager plasma-nm"
systemctl enable NetworkManager
systemctl start NetworkManager

echo -e "... images"
yaourtpkg "imagemagick guetzli geeqie  libraw"

echo -e "... musics and videos"
yaourtpkg "vlc plex-media-server-plexpass plex-media-player ffmpeg"
systemctl start plexmediaserver
systemctl enable plexmediaserver

echo -e "... to configure plex-media-server visit http://localhost:32400/web/"

packages = ''

# wireless connection with phone
packages+='sshfs '

# bluetooth
packages+='bluez bluez-utils bluedevil  pulseaudio-bluetooth bluedevil '

yaourtpkg $packages

# add the following line to /etc/bluetooth/audio.conf to allow laptop speaker as a sink
tee /etc/bluetooth/audio.conf <<EOF
[General] 
Enable=Source
EOF

# add the following lien to /etc/pulse/default.pa to auto connect to bluetooth
tee /etc/pulse/default.pa <<EOF
# automatically switch to newly-connected devices
load-module module-switch-on-connect
EOF

# Create a default user with autologin
echo -e ".. create user ulva with default password"
useradd -m -g users -G audio,disk,lp,network -s /bin/bash kiska
passwd kiska << EOF
113RoxieRd
113RoxieRd
EOF

wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/JC600/source/sddm.conf -O /etc/sddm.conf

if [[ USER_FLAG==0 ]]; then
  userdel builduser
  rm /home/builduser -R
  sed -i 's/builduser ALL=(ALL) ALL//' /etc/sudoers
fi

echo "+ add plexmediaplayer as autoboot"

exit
