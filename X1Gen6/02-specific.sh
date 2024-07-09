#/bin/bash!
# ssh megavolts@IP
USR=megavolts
alias yayr="sudo -u $USR yay -S --removemake --cleanafter --noconfirm"

echo -e ".. Install xorg and input"
yayr xorg-server xorg-apps xorg-xinit xorg-xrandr xorg-xkill xorg-xauth

echo -e "... install plasma windows manager"
yayr plasma-desktop sddm plasma-nm kscreen powerdevil plasma-wayland-session plasma-pa plasma-thunderbolt jack2 ttf-droid wireplumber phonon-qt6-gstreamer 

echo -e ".. install audio server"
yayr pipewire lib32-pipewire pipewire-docs pipewire-alsa lib32-pipewire-jack qpwgraph

echo -e ".. Installing bluetooth"
yayr bluez bluez-utils bluedevil

echo -e ".. Installing graphic tools"
yayr yakuake kdialog kfind kdeconnect barrier wl-clipboard kwallet-pam sddm-kcm xdg-desktop-portal-kde

echo -e "Install software"
echo -e ".. partition tools"
yayr gparted ntfs-3g exfat-utils mtools sshfs bindfs

echo -e "... network tools"
yayr dnsmasq nm-connection-editor openconnect networkmanager-openconnect avahi

echo -e "... android tools"
yayr android-tools android-udev  

echo -e "... installing fonts"
yayr  freefonts ttf-inconsolata ttf-hanazono ttf-hack ttf-anonymous-pro ttf-liberation gnu-free-fonts noto-fonts ttf-bitstream-vera ttf-croscore ttf-dejavu ttf-droid ttf-ibm-plex

echo -e ".. internet software"
yayr firefox thunderbird filezilla zoom teams slack-wayland telegram-desktop signal-desktop profile-sync-daemon vdhcoapp-bin
yayr pass-git protonmail-bridge-bin protonvpn-gui qtpass secret-service

# echo -e ".. media"
yayr dolphin dolphin-plugins qt6-imageformats ffmpegthumbs lzop kdegraphics-thumbnailers kimageformats raw-thumbnailer kio-gdrive libappimage rawtherapee
yayr ark unrar p7zip zip

echo -e ".. sync software"
echo -e ".. Add ownstuff repositories"
cat << EOF >>  /etc/pacman.conf
[ownstuff]
Server = https://ftp.f3l.de/~martchus/$repo/os/$arch
Server = https://martchus.no-ip.biz/repo/arch/$repo/os/$arch
EOF
pacman-key --recv-keys B9E36A7275FC61B464B67907E06FE8F53CDC6A4C # import key
pacman-key --finger    B9E36A7275FC61B464B67907E06FE8F53CDC6A4C # verify fingerprint
pacman-key --lsign-key B9E36A7275FC61B464B67907E06FE8F53CDC6A4C # sign imported key locally
yayr syncthingtray-qt6

echo -e ".. coding tools"
yayr sublime-text-4 terminator zettlr pycharm-professional python-pip python-setuptools tk python-utils

echo -e ".. python pagckages"
yayr python-utils python-numpy python-matplotlib python-scipy python-pandas python-openpyxl python-basemap python-pillow cython jupyterlab jupyter-notebook ipython 

echo -e "... viewer"
yayr okular spectacle discount kdegraphics-mobipocket 

echo -e "... images"
yayr imagemagick guetzli geeqie inkscape gimp darktable libraw hugin digikam kipi-plugins

echo -e "... musics and videos"
yayr vlc ffmpeg jellyfin-bin jellyfin-media-player picard picard-plugins-git

echo -e ".. office"
yayr libreoffice-fresh mendeleydesktop texmaker texlive-most zotero
yayr aspell-fr aspell-en aspell-de hunspell-en_US hunspell-fr hunspell-de hyphen-en hyphen-en hyphen-de libmythes mythes-en mythes-fr libreoffice-extension-grammalecte-fr

# echo -e ".. confing tools"
yayr kinfocenter kruler sonnet-git discover packagekit 

# echo -e ".. printing tools"
yayr cups system-config-printer

# echo -e ".. virtualization tools"
yayr virtualbox virtualbox-guest-iso virtualbox-host-dkms virtualbox-ext-oracle
# # For cursor in wayland session
# echo "KWIN_FORCE_SW_CURSOR=1" >> /etc/environement

# Enable snapshots with snapper
echo -e "Install snapper, a snapshots manager "
yayr snapper snapper-gui-git snap-pac


# Enable base services
echo -e ".. Start services"
systemctl enable --now sddm
systemctl enable --now cups.service
systemctl enable --now bluetooth
systemctl enable --now avahi-daemon


echo -e "Install snapper, a snapshots manager "
yayr snapper snapper-gui-git snap-pac

echo -e ".. Configure snapper"
echo -e "... Create root config"
if [ -d "/home/.snapshots" ]; then
  rmdir /.snapshots
fi
snapper -c root create-config /

echo -e "... Create home config"
if [ -d "/home/.snapshots" ]; then
  rmdir /home/.snapshots
fi
snapper -c home create-config /home

# we want the snaps located /at /mnt/btrfs-root/_snaptshot rather than at the root
echo -e ".. move snap subvolume to data root subvolume"
btrfs subvolume delete /.snapshots
btrfs subvolume delete /home/.snapshots
mkdir /.snapshots
mkdir /home/.snapshots
echo -e ".. add entry to fstab and mount"
echo "# Snapper subvolume"
echo "LABEL=arch /.snapshots      btrfs rw,noatime,ssd,discard,compress=zstd:3,space_cache,subvol=@snapshots/@root_snaps   0 0" >> /etc/fstab
echo "LABEL=arch /home/.snapshots btrfs rw,noatime,ssd,discard,compress=zstd:3,space_cache,subvol=@snapshots/@home_snaps   0 0" >> /etc/fstab
systemctl daemon-reload && mount -a

echo -e ".. Edit home and root configuration"
echo -e "... Allow user $USR to modify snapper config"
setfacl -Rm "u:${USR}:rwx" /etc/snapper/configs
setfacl -Rdm "u:${USR}:rwx" /etc/snapper/configs

echo -e "... Allow user $USR and usergroup wheel to modify snapper"
sed -i "s|ALLOW_USERS=\"|ALLOW_USERS=\"${USR}|g" /etc/snapper/configs/home
sed -i "s|ALLOW_USERS=\"|ALLOW_USERS=\"${USR}|g" /etc/snapper/configs/root
sed -i "s|ALLOW_GROUPS=\"|ALLOW_GROUPS=\"wheel|g" /etc/snapper/configs/home # Allow $NEWUSER to modify the files
sed -i "s|ALLOW_GROUPS=\"|ALLOW_GROUPS=\"wheel|g" /etc/snapper/configs/root

echo -e "... Enable ACL"
sed "s|SYNC_ACL=\"no|SYNC_ACL=\"yes|g" -i /etc/snapper/configs/home
sed "s|SYNC_ACL=\"no|SYNC_ACL=\"yes|g" -i /etc/snapper/configs/root

echo -e "... Change Timeline limit for snapshot retention"
# update snap config for home directory
sed  -i "s|TIMELINE_MIN_AGE=\"1800\"|TIMELINE_MIN_AGE=\"1800\"|g"         /etc/snapper/configs/home
sed  -i "s|TIMELINE_LIMIT_HOURLY=\"10\"|TIMELINE_LIMIT_HOURLY=\"96\"|g"   /etc/snapper/configs/home  # keep hourly backup for 48 hours
sed  -i "s|TIMELINE_LIMIT_DAILY=\"10\"|TIMELINE_LIMIT_DAILY=\"14\"|g"     /etc/snapper/configs/home  # keep daily backup for 14 days
sed  -i "s|TIMELINE_LIMIT_WEEKLY=\"0\"|TIMELINE_LIMIT_WEEKLY=\"3\"|g"     /etc/snapper/configs/home  # keep weekly backup for 4 weeks
sed  -i "s|TIMELINE_LIMIT_MONTHLY=\"10\"|TIMELINE_LIMIT_MONTHLY=\"12\"|g" /etc/snapper/configs/home  # keep monthly backup for 12 months
sed  -i "s|TIMELINE_LIMIT_YEARLY=\"10\"|TIMELINE_LIMIT_YEARLY=\"5\"|g"     /etc/snapper/configs/home  # keep yearly backup for 5 years
# update snap config for root directory
sed  -i "s|TIMELINE_MIN_AGE=\"1800\"|TIMELINE_MIN_AGE=\"0\"|g"         /etc/snapper/configs/root  # Allow all snapshots to be removed, independantly of age
sed  -i "s|TIMELINE_LIMIT_HOURLY=\"10\"|TIMELINE_LIMIT_HOURLY=\"4\"|g"   /etc/snapper/configs/root  # keep hourly backup for 4 hours
sed  -i "s|TIMELINE_LIMIT_DAILY=\"10\"|TIMELINE_LIMIT_DAILY=\"7\"|g"     /etc/snapper/configs/root  # keep daily backup for 7 days
sed  -i "s|TIMELINE_LIMIT_WEEKLY=\"0\"|TIMELINE_LIMIT_WEEKLY=\"4\"|g"     /etc/snapper/configs/root  # keep weekly backup for 4 weeks
sed  -i "s|TIMELINE_LIMIT_MONTHLY=\"10\"|TIMELINE_LIMIT_MONTHLY=\"12\"|g" /etc/snapper/configs/root  # keep monthly backup for 12 months
sed  -i "s|TIMELINE_LIMIT_YEARLY=\"10\"|TIMELINE_LIMIT_YEARLY=\"5\"|g"     /etc/snapper/configs/root  # keep yearly backup for 5 years

echo -e ".. Remove snapshots from mlocate database"
sed -i 's/PRUNENAMES = "/PRUNENAMES = ".snapshots /g' /etc/updatedb.conf

echo -e ".. Enable and start snapshots timer"
systemctl start --now snapper-timeline.timer snapper-cleanup.timer  # start and enable snapper

echo -e " ... Execute snapshots cleanup everyhour"
SYSTEMD_EDITOR=tee systemctl edit snapper-cleanup.timer <<EOF
[Timer]
OnBoot=10min
OnUnitActiveSec=1h
EOF

echo -e "... Take a snapshots every 5 minutes"
SYSTEMD_EDITOR=tee systemctl edit snapper-timeline.timer <<EOF
[Timer]
OnCalendar=*:0/5
EOF

# enable snapshot at boot
echo -e "... Take a snapshots at boot after mounting /.snapshots"
systemctl enable snapper-boot.timer
SYSTEMD_EDITOR=tee systemctl edit snapper-boot.service <<EOF
[Unit]
After=\\\\x2eboot.mount
EOF

# ------------------------------------------------------- #
# BTRFS maintenance
yayr rmling rmlint-shredder duperemove bees duperemove-service 

mkdir /opt/$USR
cat <<EOF | sudo tee -a /opt/$USR/btrfs_maintenance.sh > /dev/null
#! /bin/bash
/usr/bin/btrfs balance start -dusage=10 -dlimit=2..20 -musage=10 -mlimit=2..20 \$1 &&
/usr/bin/btrfs balance start -dusage=25 -dlimit=2..10 -musage=25 -mlimit=2..10 \$1
EOF

cat <<EOF | sudo tee -a /opt/$USR/btrfs_maintenance-scrub.sh > /dev/null
#! /bin/bash
/usr/bin/btrfs scrub start \$1 &&
/usr/bin/btrfs scrub status -d \$1
EOF

cat <<EOF | sudo tee -a /opt/$USR/btrfs_maintenance-all.sh > /dev/null
#! /bin/bash
/usr/bin/btrfs balance start -dusage=10 -dlimit=2..20 -musage=10 -mlimit=2..20 \$1 &&
/usr/bin/btrfs balance start -dusage=25 -dlimit=2..10 -musage=25 -mlimit=2..10 \$1 &&
/usr/bin/btrfs scrub start \$1 &&
/usr/bin/btrfs scrub status -d \$1 &
/usr/bin/btrfs filesystem defragment -r \$1
EOF
chmod +x /opt/$USR/*

# Set up Zerotier
yayr zerotier-one
systemctl enable --now zerotier-one.service
zerotier-cli join 233ccaac278f1c3d

# Set up tailscale
yayr tailscale
systemctl enable --now tailscaled
tailscale up --ssh
echo -e ".. Follow the link to login"

# Enable samba
echo -e ".. Install samba"
yayr samba kdenetwork-filesharing
mdir /etc/samba
echo -e "... Edit samba configuration"
wget wget -O /etc/samba/smb.conf https://raw.githubusercontent.com/zentyal/samba/master/examples/smb.conf.default
sed -i "s|   log file = /usr/local/samba/var/log.%m|#   log file = /usr/local/samba/var/log.%m|g" /etc/samba/smb.conf
sed -i "/#   log file = \/usr\/local\/samba\/var\/log.\%m/a   logging = systemd" /etc/samba/smb.conf
sed -i "s|Samba Server|Atka|g" /etc/samba/smb.conf
sed -i "s|\[homes\]|#\[homes\]|g" /etc/samba/smb.conf
sed -i "s|   comment = Home Directories|#   comment = Home Directories|g" /etc/samba/smb.conf
sed -i "s|   browseable = no|#   browseable = no|g" /etc/samba/smb.conf
sed -i "s|   writable = yes|#   writable = yes|g" /etc/samba/smb.conf
systemctl start --now smb

echo -e "... create samba user"
echo -en $PASSWORD | smbpasswd -a $USR

echo -e " ..  Install pacman and downgrade tools"
yayr paccache-hook pacman-contrib downgrade packagekit-qt6

echo -e ".. GTK integration into QT"
yayr breeze breeze-gtk xdg-desktop-portal xdg-desktop-portal plasma-browser-integration firefox-kde-opensuse

echo -e << EOF
.. For Firefox
- widget.use-xdg-dekstop-portal-mime-handler: 1
- widget.user-xdg-dekstop-portal.file-picker: 1
- media.hardwaremediakeys.enabled: false
EOF