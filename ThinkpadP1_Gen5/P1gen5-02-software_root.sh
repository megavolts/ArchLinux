# #/bin/bash!
# ssh megavolts@IP
# install graphic consol# #/bin/bash!
# ssh megavolts@IP
# install graphic consol
PASSWORD=$1
USR=$2
HOSTNAME=$3
yays(){sudo -u $USR yay -S --removemake --cleanafter --noconfirm $1}

echo -e ".. Install xorg and input"
yays xorg-server xorg-apps xorg-xinit xorg-xrandr xorg-xkill xorg-xauth

echo -e "... install plasma windows manager"
yays plasma-desktop sddm plasma-nm kscreen powerdevil plasma-wayland-session plasma-pa plasma-thunderbolt jack2 ttf-droid wireplumber phonon-qt5-gstreamer 

echo -e ".. install audio server"
yays pipewire lib32-pipewire pipewire-docs pipewire-alsa lib32-pipewire-jack qpwgraph

echo -e ".. Installing bluetooth"
yays bluez bluez-utils bluedevil
sudo systemctl enable --now bluetooth

echo -e ".. Installing graphic tools"
yays yakuake kdialog kfind kdeconnect barrier wl-clipboard kwallet-pam sddm-kcm xdg-desktop-portal-kde

echo -e "Install software"
echo -e ".. partition tools"
yays gparted ntfs-3g exfat-utils mtools sshfs bindfs

echo -e "... network tools"
yays dnsmasq nm-connection-editor openconnect networkmanager-openconnect

echo -e "... android tools"
yays android-tools android-udev  

echo -e "... installing fonts"
yays  freefonts ttf-inconsolata ttf-hanazono ttf-hack ttf-anonymous-pro ttf-liberation gnu-free-fonts noto-fonts ttf-bitstream-vera ttf-croscore ttf-dejavu ttf-droid ttf-ibm-plex

echo -e ".. internet software"
yays firefox thunderbird filezilla zoom teams slack-wayland telegram-desktop signal-desktop profile-sync-daemon vdhcoapp-bin
yays pass-git protonmail-bridge-bin protonvpn-gui qtpass secret-service

# echo -e ".. media"
yays dolphin dolphin-plugins qt5-imageformats ffmpegthumbs lzop kdegraphics-thumbnailers kimageformats raw-thumbnailer kio-gdrive libappimage
yays ark unrar p7zip zip

echo -e ".. sync software"
yays c++utilities 
yays qtutilities 
yays qtforkawesome 
yays syncthingtray syncthing nextcloud-client

echo -e ".. coding tools"
yays sublime-text-4 terminator zettlr pycharm-professional python-pip python-setuptools tk python-utils

echo -e ".. python pagckages"
yays python-utils python-numpy python-matplotlib python-scipy python-pandas python-openpyxl python-basemap python-pillow cython jupyterlab jupyter-notebook ipython 

echo -e "... viewer"
yays okular spectacle discount kdegraphics-mobipocket 

echo -e "... images"
yays imagemagick guetzli geeqie inkscape gimp darktable libraw hugin digikam kipi-plugins

echo -e "... musics and videos"
yays vlc ffmpeg jellyfin-bin jellyfin-media-player picard picard-plugins-git

echo -e ".. office"
yays libreoffice-fresh mendeleydesktop texmaker texlive-most zotero
yays aspell-fr aspell-en aspell-de hunspell-en_US hunspell-fr hunspell-de hyphen-en hyphen-en hyphen-de libmythes mythes-en mythes-fr libreoffice-extension-grammalecte-fr

# echo -e ".. confing tools"
yays kinfocenter kruler sonnet-git discover packagekit-qt5 

# echo -e ".. printing tools"
yays cups system-config-printer
systemctl enable --now cups.service

# echo -e ".. virtualization tools"
yays virtualbox virtualbox-guest-iso virtualbox-host-dkms virtualbox-ext-oracle
# # For cursor in wayland session
# echo "KWIN_FORCE_SW_CURSOR=1" >> /etc/environement

# Enable snapshots with snapper
echo -e "Install snapper, a snapshots manager "
yays snapper snapper-gut-git snap-pac

echo -e ".. Configure snapper"
echo -e "... Create root config"
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
echo "LABEL=data /.snapshots btrfs rw,noatime,ssd,discard,compress=zstd:3,space_cache,subvol=@snapshots/@root_snaps   0 0" >> /etc/fstab
echo "LABEL=data /home/.snapshots  btrfs rw,noatime,ssd,discardcompress=zstd:3,space_cache,subvol=@snapshots/@home_snaps   0 0" >> /etc/fstab
systemctl daemon-reload && mount -a

echo -e ".. Edit home and root configuration"
echo -e "... Allow user $USR to modify snapper config"
setfacl -Rm "u:$USR:rwx" /etc/snapper/configs
setfacl -Rdm "u:$USR:rwx" /etc/snapper/configs

echo -e "... Allow user $USR and usergroup wheel to modify snapper"
sed -i "s|ALLOW_USERS=\"|ALLOW_USERS=\"$USR|g" /etc/snapper/configs/home
sed -i "s|ALLOW_USERS=\"|ALLOW_USERS=\"$USR|g" /etc/snapper/configs/root
sed -i "s|ALLOW_GROUPS=\"|ALLOW_GROUPS=\"wheel|g" /etc/snapper/configs/home # Allow $NEWUSER to modify the files
sed -i "s|ALLOW_GROUPS=\"|ALLOW_GROUPS=\"wheel|g" /etc/snapper/configs/root

echo -e "... Enable ACL"
sed "s|SYNC_ACL=\"no|SYNC_ACL=\"yes|g" -i /etc/snapper/configs/root
sed "s|SYNC_ACL=\"no|SYNC_ACL=\"yesvg" -i /etc/snapper/configs/root

echo -e "... Change Timeline limit for snapshot retention"

# update snap config for home directory
sed  -i "s|TIMELINE_MIN_AGE=\"1800\"|TIMELINE_MIN_AGE=\"1800\"|g"         /etc/snapper/configs/home
sed  -i "s|TIMELINE_LIMIT_HOURLY=\"10\"|TIMELINE_LIMIT_HOURLY=\"96\"|g"   /etc/snapper/configs/home  # keep hourly backup for 48 hours
sed  -i "s|TIMELINE_LIMIT_DAILY=\"10\"|TIMELINE_LIMIT_DAILY=\"14\"|g"     /etc/snapper/configs/home  # keep daily backup for 14 days
sed  -i "s|TIMELINE_LIMIT_WEEKLY=\"0\"|TIMELINE_LIMIT_WEEKLY=\"0\"|g"     /etc/snapper/configs/home  # keep weekly backup for 4 weeks
sed  -i "s|TIMELINE_LIMIT_MONTHLY=\"10\"|TIMELINE_LIMIT_MONTHLY=\"12\"|g" /etc/snapper/configs/home  # keep monthly backup for 12 months
sed  -i "s|TIMELINE_LIMIT_YEARLY=\"10\"|TIMELINE_LIMIT_YEARLY=\"5\"|g"     /etc/snapper/configs/home  # keep yearly backup for 5 years

echo -e ".. Remove snapshots from mlocate database"
sed -i 's/PRUNENAMES = "/PRUNENAMES = ".snapshots /g' /etc/updatedb.conf

echo -e ".. Enable and start snapshots timer"
systemctl start --now snapper-timeline.timer snapper-cleanup.timer  # start and enable snapper

echo -e " ... Execute snapshots cleanup everyhour"
SYSTEMD_EDITOR=tee systemctl edit snapper-cleanup.timer <<EOF
[Timer]
OnUnitActiveSec=1h
EOF

echo -e "... Take a snapshots every 5 minutes"
SYSTEMD_EDITOR=tee systemctl edit snapper-timeline.timer <<EOF
[Timer]
OnCalendar=*:0\/5/
EOF

# enable snapshot at boot
echo -e "... Take a snapshots at boot"
systemctl enable snapper-boot.timer

# BTRFS maintenance
yays rmling shredder-rmlint duperemove bees

echo -e ".. Configure bees"
for BTRFS_DEV in root database
do
  BTRFS_DEV=root  
  UUID_DEV=$(blkid -s UUID -o value /dev/mapper/$BTRFS_DEV)
  mkdir -p /var/lib/bees
  # create bees subvolume on root of root
  btrfs subvolume create /var/lib/bees/@bees_$BTRFS_DEV
  truncate -s 1g /var/lib/bees/@bees_$BTRFS_DEV/beeshah.dat
  chmod 700 /var/lib/bees/@bees_$BTRFS_DEV/beeshash.dat


  cp /etc/bees/beesd.conf.sample /etc/bees/$BTRFS_DEV.conf
  sed -i "s/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/$UUID_DEV/g" /etc/bees/$BTRFS_DEV.conf
  echo "DB_SIZE=1073741824" /etc/bees/$BTRFS_DEV.conf
  systemctl enable --now beesd@UUID_DEV
done

systemctl enable --now sddm



########################################################################
# # For cursor in wayland session
# echo "KWIN_FORCE_SW_CURSOR=1" >> /etc/environement



# # IF ISSUE CHECK TO INSTALL
# sddm-git
# echo "KWallet login"
# echo "auth            optional        pam_kwallet5.so" >> /etc/pam.d/sddm
# echo "session         optional        pam_kwallet5.so auto_start" >> /etc/pam.d/sddm


# # IF pass git is required, install pass-git
# sudo -u megavolts yay -S --noconfirm pass-git


# # FIX user permssion in folder
# find ~ \! -uid `id -u` -o \! -gid `id -g`