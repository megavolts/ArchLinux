USER = megavolts
USERM = roxie

yaourtpkg() {
  sudo -u $USER bash -c "yaourt -S --noconfirm $1"
}

# create media tank
mkfs.btrfs -L tank-media -m raid1 -draid1 /dev/sdb1 /dev/sdc1 -f

mkdir -p /mnt/btrfs-media/

mount -o defaults,relatime,discard,ssd,nodev,nosuid /dev/disk/by-label/tank-media /mnt/btrfs-tank-media

mkdir -p /mnt/btrfs-tank-media/_snapshot
mkdir -p /mnt/btrfs-tank-media/_active

btrfs subvolume create /mnt/btrfs-media/_active/@musics
btrfs subvolume create /mnt/btrfs-media/_active/@movies

echo "LABEL=tank-media       /mnt/btrfs-media btrfs           rw,nosuid,nodev,relatime,ssd,space_cache,compress=zstd  0 0"

# backup of snapshots:
# Source: https://ramsdenj.com/2016/04/05/using-btrfs-for-easy-backup-and-rollback.html
yaourtpkg btrbk
mkdir -p /mnt/btrfs-tank-media/_snapshot/btrbk_snaps_bk
btrfs subvolume create /mnt/btrfs-tank-media/_snapshot/btrbk_snaps_bk/root
btrfs subvolume create /mnt/btrfs-tank-media/_snapshot/btrbk_snaps_bk/home


### Progs
echo -e ".. Install xorg and input"
pacman -S --noconfirm xorg-server xorg-apps xorg-xinit xorg-xrandr xf86-video-ati mesa-vdpau lib32-mesa-vdpau libva-vdpau-driver<<EOF
all
1
EOF


## add radeon to module in mkinit.cpio

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

echo -e "Install desktop manager"
echo -e "... install xfce  windows manager"
pacman -S --noconfirm xfce4 

echo -e "Install software"
echo -e ".. basic tools"
yaourtpkg "gnome-keyring thunar-archive-plugin thunar-media-tags-plugin ffmpegthumbnailer poppler-glib libgsf libopenraw unrar p7zip unzip ntfs-3g xorg-xkill tilda arp-scan"

yaourtpkg "nextcloud-client networkmanagerr"
systemctl stop dhcpcd
systemctl disable dhcpcd
systemctl start NetworkManager
systemctl enable NetworkManager

echo -e ".. coding tools"
yaourtpkg "sublime-text-dev"


echo -e "... images"
yaourtpkg "imagemagick guetzli geeqie libraw"

echo -e "... musics and videos"
yaourtpkg "vlc plex-media-server-plexpass plex-media-player ffmpeg"
systemctl start plexmediaserver
systemctl enable plexmediaserver
echo -e "... to configure plex-media-server visit http://localhost:32400/web/"

yaourtpkg "synergy"

echo -e "... install SoundSystem"
yaourtpkg "pulseaudio pusleuadio-alsa pulseaudio-bluetooth pulseaudio-equalizer pulseaudio-jack pavucontrol xfce4-pulseaudi-mixer paprefs pa-applet-git"

echo -e "... install lightdm session manager"
yaourtpkg "lightdm lightdm-gtk-greeter"
systemctl enable lightdm
systemctl start lightdm

echo -e "... setup wake on lan WoL"

echo -e "... Setup bluetooth"
yaourtpkg "bluez bluez-utils bluedevil  pulseaudio-bluetooth"
systemctl start bluetooth.service
systemctl enable bluetooth.service

echo "load-module module-bluetooth-policy" >> /etc/pulse/system.pa
echo "load-module module-bluetooth-discover" >> /etc/pulse/system.pa

# power on bluetooth dongle
sed  's/#AutoEnable=false/AutoEnable=true/g' -i /etc/bluetooth/main.conf
# wireless connection with phone
packages+='sshfs'ee

# adding a multmedia user

mlocate

# bluetooth
# VNC
yaourt -S tigervnc 

# Add multimedia user "Roxie:113Roxie"
echo -e ".. create user roxie:113Roxie"
useradd -m -g users -G audio,disk,lp,network -s /bin/zsh roxie
passwd roxie << EOF
113Roxie
113Roxie
EOF

# configure headleass
tee /etc/X11/xorg.conf.d/05-screen.conf <<EOF
Section "Monitor"
        Identifier "HDMI-0"

EndSection

Section "Device"
        Identifier "Radeon"
        Driver "radeon"
        BusID  "PCI:1:0:0"  # Actual location of card0 CEDAR
        Option "HDMI" "HDMI-A-1"  # Actual connector as reported by /sys/class/drm/card0-xx
EndSection

Section "Screen"
        Identifier "Screen0"
        Device "Radeon"
        Monitor "HDMI"
        SubSection "Display"
                Depth 24 Modes "1024x768"
        EndSubSection
EndSection
EOF

yaourt -S -noconfirm nodm
sed  "s/NODM_USER='{user}'/NODM_USER=roxie/g" -i /etc/nodm/.conf
sed  "s/NODM_XSESSION='\/home\/{user}\/.xinitrc'/NODM_XSESSION=\/home\/roxie\/.xinitrc/g" -i /etc/nodm.conf
echo "startxfce4" >> /home/roxie/.xinitrc
chown roxie:users /home/roxie/.xinitrc
chmod +x /home/roxie/.xinitrc
tee /etc/pam.d/nodm <<EOF
#%PAM-1.0

auth      include   system-local-login
account   include   system-local-login
password  include   system-local-login
session   include   system-local-login
EOF

#set up VNC server
yaourt -S tigervnc

vncserver <<EOF
113Roxie
113Roxie
n
EOF


# set plex and tilda to start at boot



