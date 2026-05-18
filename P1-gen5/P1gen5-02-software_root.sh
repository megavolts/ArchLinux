# #/bin/bash!
# ssh megavolts@IP
# install graphic consol# #/bin/bash!
# ssh megavolts@IP
# install graphic consol

NEWUSER=megavolts
HOME_DISK_LABEL=data
echo 'Enter a default passphrase use to encrypt the disk and serve as password for root and megavolts:'
stty -echo
read PASSWORD
yay --sudo doas --sudoflags -- --save
yays(){yay -S --removemake --cleanafter --noconfirm $@}

# Packages list redone as 2025-04-02
echo -e "... install plasma windows manager"
yays plasma-desktop pipewire-jack qt6-multimedia-ffmpeg plasma-thunderbolt pinentry kwalletmanager kwallet-pam kinfocenter kruler plasma-login-manager
systemctl enable --now plasmalogin.service

# Power
yays powerdevil power-profiles-daemon
systemctl enable --now power-profiles-daemon

# Set up tailscale
echo -e ".. Installing tailscale, follow the link to login"
yays tailscale trayscale
systemctl enable --now tailscaled
tailscale up --ssh --accept-routes

# Sound
echo -e ".. install audio server"
yays pipewire wireplumber pavucontrol plasma-pa 

echo -e ".. Installing graphic tools"
yays yakuake kdialog kfind kdeconnect deskflow kscreen wl-clipboard xdg-desktop-portal-kde colord-kde

echo -e ".. Installing bluetooth"
yays bluez bluez-utils bluedevil
systemctl enable --now bluetooth

echo -e "Install software"
echo -e ".. partition tools"
yays gparted ntfs-3g exfatprogs mtools sshfs dosfstools bindfs

echo -e "... network tools"
yays plasma-nm networkmanager-openvpn
#yays dnsmasq nm-connection-editor openconnect networkmanager-openconnect  avahi plasma-nm hostapd
#systemctl enable --now avahi-daemon

echo -e ".. file manager"
yays dolphin dolphin-plugins ark p7zip zip ffmpegthumbs kdegraphics-thumbnailers kdenetwork-filesharing kdf kio-admin kompare purpose

echo -e "... android tools"
yays android-tools android-udev 

echo -e ".. internet software"
yays firefox thunderbird filezilla zoom slack-wayland transmission-qt hunspell-en_US

echo -e ".. sync software"
yays c++utilities qtutilities-qt6 qtforkawesome-qt6 syncthingtray-qt6 nextcloud-client 

echo -e "... viewer"
yays okular spectacle

echo -e "... images"
yays imagemagick guetzli geeqie inkscape gimp darktable inkscape libraw hugin

echo -e ".. coding tools"
yays sublime-text-4 terminator code 
# pycharm-professional code

echo -e "... musics and videos"
yays vlc ffmpeg vlc-plugins-all
# rdp6 libvncserver krdc krfb

echo -e ".. office"
yays libreoffice-fresh libreoffice-extension-texmaths zotero-bin
yays aspell-fr aspell-en aspell-de hunspell-en_US hunspell-fr hunspell-de hyphen-en hyphen-en hyphen-de libmythes mythes-en mythes-fr libreoffice-extension-grammalecte-fr

echo -e ".. printing tools"
# yays cups system-config-printer print-manager
# systemctl enable --now cups.service

echo -e ".. virtualization tools"
yays virtualbox virtualbox-guest-iso virtualbox-host-dkms virtualbox-ext-oracle

echo -e ".. Utilties toolbox"
yays solaar 

echo -e " ..  Install pacman and downgrade tools"
yays paccache-hook pacman-contrib downgrade

# Enable snapshots with snapper
echo -e "Install snapper, a snapshots manager "
yays snapper snapper-gui-git snap-pac

# Enable snapshots with snapper
echo -e ".. Configure snapper"
echo -e "... Create root config"

# Delete any /.snapshots directory or subvolume
if [ -d "/.snapshots" ]; then
  rmdir /.snapshots
fi
snapper -c root create-config /
btrfs subvolume delete /.snapshots
mkdir /.snapshots
if ! [ -d /storage/btrfs/root/@snapshots/@root_snaps ] ; then
  if ! [ -d /storage/btrfs/root/@snapshots ] ; then
    doas btrfs subvolume create /storage/btrfs/root/@snapshots
  fi
  doas btrfs subvolume create /storage/btrfs/root/@snapshots/@root_snaps

if [ -d "/home/.snapshots" ]; then
  rmdir /home/.snapshots
fi
snapper -c home create-config /home
btrfs subvolume delete /home/.snapshots
mkdir /home/.snapshots

if ! [ -d /storage/btrfs/$HOME_DISK_LABEL/@snapshots/@home_snaps ] ; then
  if ! [ -d /storage/btrfs/$HOME_DISK_LABEL/@snapshots ] ; then
    btrfs subvolume create /storage/btrfs/$HOME_DISK_LABEL/@snapshots
  fi
  btrfs subvolume create /storage/btrfs/$HOME_DISK_LABEL/@snapshots/@home_snaps
fi

echo -e ".. add entry to fstab and mount"
echo "# Snapper subvolume"
echo "LABEL=root /.snapshots btrfs rw,noatime,compress=zstd,subvol=@snapshots/@root_snaps   0 0" >> /etc/fstab
echo "LABEL=$HOME_DISK_LABEL /home/.snapshots btrfs rw,noatime,compress=zstd,subvol=@snapshots/@home_snaps   0 0" >> /etc/fstab
systemctl daemon-reload && mount -a

echo -e ".. Edit home and root configuration"
echo -e "... Allow user $NEWUSER to modify snapper config"
setfacl -Rm "u:${NEWUSER}:rwx" /etc/snapper/configs
setfacl -Rdm "u:${NEWUSER}:rwx" /etc/snapper/configs

echo -e "... Allow user $NEWUSER and usergroup wheel to modify snapper"
sed -i "s|ALLOW_USERS=\"|ALLOW_USERS=\"${NEWUSER}|g" /etc/snapper/configs/root
sed -i "s|ALLOW_GROUPS=\"|ALLOW_GROUPS=\"wheel|g" /etc/snapper/configs/root
sed -i "s|ALLOW_USERS=\"|ALLOW_USERS=\"${NEWUSER}|g" /etc/snapper/configs/home
sed -i "s|ALLOW_GROUPS=\"|ALLOW_GROUPS=\"wheel|g" /etc/snapper/configs/home
echo -e "... Enable ACL"
sed "s|SYNC_ACL=\"no|SYNC_ACL=\"yes|g" -i /etc/snapper/configs/root
sed "s|SYNC_ACL=\"no|SYNC_ACL=\"yes|g" -i /etc/snapper/configs/home
echo -e "... Change Timeline limit for snapshot retention"
# update snap config for root directory
sed  -i "s|TIMELINE_MIN_AGE=\"3600\"|TIMELINE_MIN_AGE=\"0\"|g"         /etc/snapper/configs/root  # Allow all snapshots to be removed, independantly of age
sed  -i "s|TIMELINE_LIMIT_HOURLY=\"10\"|TIMELINE_LIMIT_HOURLY=\"12\"|g"   /etc/snapper/configs/root  # keep hourly backup for 12 hours
sed  -i "s|TIMELINE_LIMIT_DAILY=\"10\"|TIMELINE_LIMIT_DAILY=\"7\"|g"     /etc/snapper/configs/root  # keep daily backup for 7 days
sed  -i "s|TIMELINE_LIMIT_WEEKLY=\"0\"|TIMELINE_LIMIT_WEEKLY=\"4\"|g"     /etc/snapper/configs/root  # keep weekly backup for 4 weeks
sed  -i "s|TIMELINE_LIMIT_MONTHLY=\"12\"|TIMELINE_LIMIT_MONTHLY=\"12\"|g" /etc/snapper/configs/root  # keep monthly backup for 12 months
sed  -i "s|TIMELINE_LIMIT_YEARLY=\"5\"|TIMELINE_LIMIT_YEARLY=\"5\"|g"     /etc/snapper/configs/root  # keep yearly backup for 5 years
# # update snap config for home directory
sed  -i "s|TIMELINE_MIN_AGE=\"3600\"|TIMELINE_MIN_AGE=\"1800\"|g"         /etc/snapper/configs/home
sed  -i "s|TIMELINE_LIMIT_HOURLY=\"10\"|TIMELINE_LIMIT_HOURLY=\"96\"|g"   /etc/snapper/configs/home  # keep hourly backup for 48 hours
sed  -i "s|TIMELINE_LIMIT_DAILY=\"10\"|TIMELINE_LIMIT_DAILY=\"14\"|g"     /etc/snapper/configs/home  # keep daily backup for 14 days
sed  -i "s|TIMELINE_LIMIT_WEEKLY=\"0\"|TIMELINE_LIMIT_WEEKLY=\"4\"|g"     /etc/snapper/configs/home  # keep weekly backup for 4 weeks
sed  -i "s|TIMELINE_LIMIT_MONTHLY=\"10\"|TIMELINE_LIMIT_MONTHLY=\"12\"|g" /etc/snapper/configs/home  # keep monthly backup for 12 months
sed  -i "s|TIMELINE_LIMIT_YEARLY=\"10\"|TIMELINE_LIMIT_YEARLY=\"5\"|g"     /etc/snapper/configs/home  # keep yearly backup for 5 years

echo -e ".. Remove snapshots from mlocate database"
sed -i 's/PRUNENAMES = "/PRUNENAMES = ".snapshots /g' /etc/updatedb.conf


echo -e ".. Enable and start snapshots timer"
systemctl start --now snapper-timeline.timer snapper-cleanup.timer snapper-boot.timer # start and enable snapper

echo -e " ... Execute snapshots cleanup everyhour"
SYSTEMD_EDITOR=tee systemctl edit snapper-cleanup.timer <<EOF
[Timer]
OnBootSec=10min
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


yay -S --noconfirm protonmail-bridge protonvpn-gui 
# Set up oh-my-zsh
yay -S --noconfirm oh-my-zsh-git
yay -S docker docker-compose



# Enable samba
echo -e ".. Install samba"
yays samba kdenetwork-filesharing
mkdir -p /etc/samba
echo -e "... Edit samba configuration"
wget -O /etc/samba/smb.conf https://raw.githubusercontent.com/zentyal/samba/master/examples/smb.conf.default
sed -i "s|   log file = /usr/local/samba/var/log.%m|#   log file = /usr/local/samba/var/log.%m|g" /etc/samba/smb.conf
sed -i "/#   log file = \/usr\/local\/samba\/var\/log.\%m/a   logging = systemd" /etc/samba/smb.conf
sed -i "s|Samba Server|Atka|g" /etc/samba/smb.conf
sed -i "s|\[homes\]|#\[homes\]|g" /etc/samba/smb.conf
sed -i "s|   comment = Home Directories|#   comment = Home Directories|g" /etc/samba/smb.conf
sed -i "s|   browseable = no|#   browseable = no|g" /etc/samba/smb.conf
sed -i "s|   writable = yes|#   writable = yes|g" /etc/samba/smb.conf
systemctl enable --now smb

echo -e "... create samba user"
sudo smbpasswd -a $NEWUSER << EOF
$PASSWORD
$PASSWORD
EOF




# Image format
# qt6-imageformats lzop kdegraphics-thumbnailers kimageformats raw-thumbnailer kio-gdrive libappimage rawtherapee

# FONT
# ttf-droid

# echo -e ".. python pagckages"
# yays python-utils python-pipx python-setuptools python-utils python-numpy python-matplotlib python-scipy python-pandas python-openpyxl python-basemap python-pillow cython jupyterlab jupyter-notebook ipython  python-pyclipper




# KDE and GTK uniform
# echo -e ".. GTK integration into QT"
# yays qt6ct-kde kde-gtk-config adwaita-qt6-git gtk3 qt6ct 
# yays breeze breeze-gtk xdg-desktop-portal xdg-desktop-portal-kde kde-gtk-config

# yays plasma-browser-integration firefox-kde-opensuse

########################################################################
# # For cursor in wayland session
# echo "KWIN_FORCE_SW_CURSOR=1" >> /etc/environement



# # IF ISSUE CHECK TO INSTALL
# sddm-git
echo "KWallet login"
echo "auth            optional        pam_kwallet5.so" >> /etc/pam.d/sddm
echo "session         optional        pam_kwallet5.so auto_start" >> /etc/pam.d/sddm


# # IF pass git is required, install pass-git
# sudo -u megavolts yay -S --noconfirm pass-git


# # FIX user permssion in folder
# find ~ \! -uid `id -u` -o \! -gid `id -g`
