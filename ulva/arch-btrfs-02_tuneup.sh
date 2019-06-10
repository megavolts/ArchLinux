USER=megavolts
USERM=roxie
USER_PWD=113Roxie
TANK1=/dev/sdc
TANK2=/dev/sdd

pacman -S --noconfirm gptfdisk mlocate
updatedb
sgdisk --zap-all $TANK1
sgdisk --zap-all $TANK2
sgdisk -n 1:0:0 -t 1:8300 -c 1:"TANK-MEDIA1" $TANK1
sgdisk -n 1:0:0 -t 1:8300 -c 1:"TANK-MEDIA1_MIRROR" $TANK2

# create media tank
mkfs.btrfs -f -L tank-media -m raid1 -draid1 ${TANK1}1 ${TANK2}1 -f

mkdir -p /mnt/btrfs-tank-media/
mount -o defaults,relatime,nodev,compress=lzo /dev/disk/by-label/tank-media /mnt/btrfs-tank-media

mkdir -p /mnt/btrfs-tank-media/_snapshot
mkdir -p /mnt/btrfs-tank-media/_active

btrfs subvolume create /mnt/btrfs-tank-media/_active/@musics
btrfs subvolume create /mnt/btrfs-tank-media/_active/@movies

echo "# Data subvolumes" >> /etc/fstab
mkdir -p /mnt/data/media/musics
echo "LABEL=tank-media  /mnt/data/media/musics  btrfs rw,noatime,compress=lzo,space_cache,subvol=_active/@musics   0 0" >> /etc/fstab

yaourtpkg acl
setfacl -m "u:roxie:rw" /mnt/data/media/musics

# Add multimedia user "Roxie:113Roxie"
echo -e ".. create user roxie:113Roxie"
useradd -m -g users -G audio,disk,lp,network -s /bin/zsh $USERM
passwd $USERM <<EOF
$USER_PWD
$USER_PWD
EOF

### Progs
echo -e ".. Install xorg and input"
pacman -S --noconfirm xorg-server xorg-apps xorg-xinit xorg-xrandr xf86-video-ati mesa-vdpau lib32-mesa-vdpau libva-vdpau-driver<<EOF
all
1
EOF

sed 's/MODULES=(/MODULES=(radeon /g' -i /etc/mkinitcpio.conf 

# Function
buildpkg(){
  CURRENT_DIR=$pwd
  wget https://aur.archlinux.org/cgit/aur.git/snapshot/$1.tar.gz
  tar -xvzf $1.tar.gz -C /home/$USER
  chown ${USER}:users /home/$USER/$1 -R
  cd /home/$USER/$1
  sudo -u $USER bash -c "makepkg -si --noconfirm"
  cd $CURRENT_dir 
  rm /home/$USER/$1 -R
  rm /home/$USER/$1.tar.gz
}

buildpkg package-query
buildpkg yaourt

yaourtpkg() {
  sudo -u $USER bash -c "yaourt -S --noconfirm $1"
}

echo -e "Install desktop manager"
echo -e "... install xfce  windows manager"
pacman -S --noconfirm xfce4 

echo -e "Install software"
echo -e ".. basic tools"
yaourtpkg "gnome-keyring seahorse sublime-text-dev thunar-archive-plugin thunar-media-tags-plugin ffmpegthumbnailer poppler-glib libgsf libopenraw unrar p7zip unzip ntfs-3g tilda arp-scan"
tee /etc/pam.d/pam_gnome_keyring.so << EOF
#%PAM-1.0
auth     optional  pam_gnome_keyring.so
session  optional  pam_gnome_keyring.so auto_start
EOF

echo -e "... images"
yaourtpkg "imagemagick guetzli geeqie libraw"

echo -e "... musics and videos"
yaourtpkg "vlc plex-media-server-plexpass plex-media-player ffmpeg"
systemctl start plexmediaserver
systemctl enable plexmediaserver
echo -e "... to configure plex-media-server visit http://localhost:32400/web/"
tee /home/roxie/.config/plex.desktop <<EOF
[Desktop Entry]
Encoding=UTF-8
Version=0.9.4
Type=Application
Name=plex
Comment=plex
Exec=plexmediaplayer
OnlyShowIn=XFCE;
StartupNotify=false
Terminal=false
Hidden=false
EOF
chown roxie:users /home/roxie/.config/plex.desktop

echo -e "... install SoundSystem"
yaourtpkg "pulseaudio pulseaudio-alsa pulseaudio-bluetooth pulseaudio-equalizer pulseaudio-jack pavucontrol xfce4-pulseaudio-plugin paprefs pa-applet-git"

echo -e "... Setup bluetooth"
yaourtpkg "bluez bluez-utils bluedevil  pulseaudio-bluetooth mlocate"
systemctl start bluetooth.service
systemctl enable bluetooth.service
update db

echo "load-module module-bluetooth-policy" >> /etc/pulse/system.pa
echo "load-module module-bluetooth-discover" >> /etc/pulse/system.pa
sed  's/#AutoEnable=false/AutoEnable=true/g' -i /etc/bluetooth/main.conf # power on bluetooth dongle

# Install VNC
echo -e "... Configure VNC server"
yaourtpkg "tigervnc"
sudo -u $USERM bash -c "vncserver <<EOF
113Roxie
113Roxie
n
EOF"
sudo -u $USERM bash -c "vncserver -kill :1   "
tee /home/roxie/.config/x0vncserver-start.sh <<EOF
#!/bin/bash
x0vncserver -rfbauth ~/.vnc/passwd &
EOF
chown roxie:users /home/roxie/.config/x0vncserver-start.sh 
chmod +x /home/roxie/.config/x0vncserver-start.sh 

tee /home/roxie/.config/x0vncserver.desktop <<EOF
[Desktop Entry]
Encoding=UTF-8
Version=0.9.4
Type=Application
Name=x0vncserver
Comment=x0vncserver
Exec=/home/roxie/.config/x0vncserver-start.sh
OnlyShowIn=XFCE;
StartupNotify=false
Terminal=false
Hidden=false
EOF
chown roxie:users /home/roxie/.config/x0vncserver.desktop

# Install cloud sync
yaourtpkg "nextcloud-client firefox"

# Install login manager
echo -e "... Configure login manager"
yaourtpkg " nodm"

sed  "s/NODM_USER='{user}'/NODM_USER=roxie/g" -i /etc/nodm.conf
sed  "s/NODM_XSESSION='\/home\/{user}\/.xinitrc'/NODM_XSESSION=\/home\/roxie\/.xinitrc/g" -i /etc/nodm.conf
echo "startxfce4" >> /home/roxie/.xinitrc
chown roxie:users /home/roxie/.xinitrc
chmod +x /home/roxie/.xinitrc
tee /etc/pam.d/nodm << EOF
#%PAM-1.0
auth      include   system-local-login
account   include   system-local-login
password  include   system-local-login
session   include   system-local-login
EOF

sed '/^ExecStart=\/usr\/bin\/nodm.*/a Restart=always' -i /usr/lib/systemd/system/nodm.service 
sed '/^Restart=always.*/a RestartSec=30' -i /usr/lib/systemd/system/nodm.service 
systemctl start nodm

# Install snapshot manager
echo -e " Install snapshots manager"
yaourtpkg "snapper snapper-gui-git btrbk mbuffer"

echo -e "... >> Configure snapper"
snapper -c root create-config /
snapper -c home create-config /home

# we want the snaps located /at /mnt/btrfs-root/_snapthot rather than at the root
btrfs subvolume delete /.snapshots
btrfs subvolume delete /home/.snapshots

btrfs subvolume create /mnt/btrfs-arch/_snapshot/@root_snaps
btrfs subvolume create /mnt/btrfs-arch/_snapshot/@home_snaps

# mount subvolume to original snapper subvolume
mkdir /.snapshots
mkdir /home/.snapshots
mount -o compress=lzo,subvol=_snapshot/@home_snaps /dev/disk/by-label/arch /home/.snapshots
mount -o compress=lzo,subvol=_snapshot/@root_snaps /dev/disk/by-label/arch /.snapshots

echo "# Snapper subvolume" >> /etc/fstab # add snapper subvolume to fsta
echo "LABEL=arch  /.snapshots btrfs rw,noatime,ssd,discard,compress=lzo,space_cache,subvol=_snapshot/@root_snaps   0 0" >> /etc/fstab
echo "LABEL=arch  /home/.snapshots  btrfs rw,noatime,ssd,discardcompress=lzo,space_cache,subvol=_snapshot/@home_snaps   0 0" >> /etc/fstab

sed -i "s/ALLOW_USERS=\"/ALLOW_USERS=\"$USER/g" /etc/snapper/configs/home # Allow $USER to modify the files
sed -i "s/ALLOW_USERS=\"/ALLOW_USERS=\"$USER/g" /etc/snapper/configs/root
sed 's/PRUNENAMES = "/PRUNENAMES = ".snapshots /g' -i /etc/updatedb.conf # do not index snapshot via mlocate
systemctl start snapper-timeline.timer snapper-cleanup.timer  # start and enable snapper
systemctl enable snapper-timeline.timer snapper-cleanup.timer

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

# permission manager
yaourtpkg "acl"


## mount musics subvolume



# backup of snapshots:
# Source: https://ramsdenj.com/2016/04/05/using-btrfs-for-easy-backup-and-rollback.html
mkdir -p /mnt/btrfs-tank-media/_snapshot/btrbk_snaps_bk
btrfs subvolume create /mnt/btrfs-tank-media/_snapshot/btrbk_snaps_bk/root
btrfs subvolume create /mnt/btrfs-tank-media/_snapshot/btrbk_snaps_bk/home

echo -e "... setup wake on lan WoL"
#yaourtpkg "synergy"
