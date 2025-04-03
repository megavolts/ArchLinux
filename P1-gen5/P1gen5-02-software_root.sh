# #/bin/bash!
# ssh megavolts@IP
# install graphic consol# #/bin/bash!
# ssh megavolts@IP
# install graphic consol


NEWUSER=megavolts
echo 'Enter a default passphrase use to encrypt the disk and serve as password for root and megavolts:'
stty -echo
read PASSWORD
yays(){sudo -u $NEWUSER yay -S --removemake --cleanafter --noconfirm $@}


# Set up tailscale
echo -e ".. Installing tailscale, follow the link to login"
yays tailscale
systemctl enable --now tailscaled
tailscale up --ssh

# Disable build of debug packages
echo -e "... disable build of debug packge when using makepkg"
sed -i "s| debug lto| \!debug lto|g" /etc/makepkg.conf

# echo -e "... set up unified kernel image"
# yays systemd-ukify
# echo -e ".... conigure mkinitcpio.d/"

# # Rebuild kernel for unified kernel efi
# mkdir /boot/EFI/Linux
# if [ -f /boot/vmlinuz-linux ]; then
#   echo -e "DO ..."
# fi

# if [ -f /boot/vmlinuz-linux-zen ]; then
#   sed -i "s|default_image=|#default_image=|g" /etc/mkinitcpio.d/linux-zen.preset
#   sed -i "s|#default_uki=|default_uki=|g" /etc/mkinitcpio.d/linux-zen.preset
#   sed -i "s|#default_options=|default_options=|g" /etc/mkinitcpio.d/linux-zen.preset

#   sed -i "s|fallback_image=|#fallback_image=|g" /etc/mkinitcpio.d/linux-zen.preset
#   sed -i "s|#fallback_uki=|fallback_uki=|g" /etc/mkinitcpio.d/linux-zen.preset
#   sed -i "s|#fallback_options=|fallback_options=|g" /etc/mkinitcpio.d/linux-zen.preset

#   sed -i "s|=\"/efi|=\"/boot|g" /etc/mkinitcpio.d/linux-zen.preset

#   # Modify kernel line option
#   wget https://raw.githubusercontent.com/megavolts/ArchLinux/refs/heads/master/X1Gen6/sources/cmdline.conf -O /etc/kernel/cmdline

#   # Change 
#   mkinitcpio -p linux-zen 
#   rm /boot/*zen*.img
#   rm /boot/vmlinuz-linux-zen
#   rm /boot/intel-ucode.img
# fi

# Packages list redone as 2025-04-02
echo -e "... install plasma windows manager"
yays plasma-dekstop sddm sddm-kcm pipewire-jack qt6-multimedia-ffmpeg plasma-thunderbolt kwalletcli pinentry kwalletmanager kwallet-pam kinfocenter kruler
systemctl enable sddm

# Power
yays powerdevil power-profiles-daemon
systemctl enable power-profiles-daemon

# Sound
echo -e ".. install audio server"
yays pipewire wireplumber pavucontrol plasma-pa 

echo -e ".. Installing graphic tools"
yays yakuake kdialog kfind kdeconnect deskflow kscreen wl-clipboard xdg-desktop-portal-kde colord-kde

echo -e ".. Installing bluetooth"
yays bluez bluez-utils bluedevil
systemctl enable bluetooth

echo -e "Install software"
echo -e ".. partition tools"
yays gparted ntfs-3g exfat-utils mtools sshfs dosfstools bindfs

echo -e "... network tools"
yays dnsmasq nm-connection-editor openconnect networkmanager-openconnect avahi plasma-nm tailscale hostapd
systemctl enable --now avahi-daemon
systemctl enable --now tailscaled

echo -e ".. file manager"f
yays dolphin dolphin-plugins ark p7zip zip

echo -e "... android tools"
yays android-tools android-udev 

echo -e ".. internet software"
yays firefox thunderbird filezilla zoom slack-wayland transmission-qt

echo -e ".. sync software"
yays c++utilities qtutilities-qt6 qtforkawesome-qt6 syncthingtray-qt6 nextcloud-client 

echo -e "... viewer"
yays okular spectacle

echo -e "... images"
yays imagemagick guetzli geeqie inkscape gimp darktable inkscape libraw hugin

echo -e ".. coding tools"
yays sublime-text-4 terminator pycharm-professional code

echo -e "... musics and videos"
yays vlc ffmpeg rdp6 libvncserver

echo -e ".. office"
yays libreoffice-fresh libreoffice-extension-texmaths mendeleydesktop zotero-bin
yays aspell-fr aspell-en aspell-de hunspell-en_US hunspell-fr hunspell-de hyphen-en hyphen-en hyphen-de libmythes mythes-en mythes-fr libreoffice-extension-grammalecte-fr

echo -e ".. printing tools"
yays cups system-config-printer print-manager
systemctl enable --now cups.service

echo -e ".. virtualization tools"
yays virtualbox virtualbox-guest-iso virtualbox-host-dkms virtualbox-ext-oracle

echo -e ".. Utilties toolbox"
yays solaar krdc

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

echo -e " ..  Install pacman and downgrade tools"
yays paccache-hook pacman-contrib downgrade

# Enable snapshots with snapper
echo -e "Install snapper, a snapshots manager "
yays snapper snapper-gui-git snap-pac

echo -e ".. Configure snapper"
echo -e "... Create root config"
if [ -d "/.snapshots" ]; then
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
if ! [ -d /storage/btrfs/root/@snapshots/@root_snaps ] ; then
  if ! [ -d /storage/btrfs/root/@snapshots ] ; then
    btrfs subvolume create /storage/btrfs/root/@snapshots
  fi
  btrfs subvolume create /storage/btrfs/root/@snapshots/@root_snaps
fi
mkdir /home/.snapshots
if ! [ -d /storage/btrfs/data/@snapshots/@home_snaps ] ; then
  if ! [ -d /storage/btrfs/data/@snapshots/ ] ; then
    btrfs subvolume create /storage/btrfs/data/@snapshots
  fi
  btrfs subvolume create /storage/btrfs/data/@snapshots/@home_snaps
fi
echo -e ".. add entry to fstab and mount"
echo "# Snapper subvolume"
echo "LABEL=arch /.snapshots btrfs rw,noatime,compress=zstd,subvol=@snapshots/@root_snaps   0 0" >> /etc/fstab
echo "LABEL=data /home/.snapshots  btrfs rw,noatime,compress=zstd,subvol=@snapshots/@home_snaps   0 0" >> /etc/fstab
systemctl daemon-reload && mount -a

echo -e ".. Edit home and root configuration"
echo -e "... Allow user $NEWUSER to modify snapper config"
setfacl -Rm "u:${NEWUSER}:rwx" /etc/snapper/configs
setfacl -Rdm "u:${NEWUSER}:rwx" /etc/snapper/configs

echo -e "... Allow user $NEWUSER and usergroup wheel to modify snapper"
sed -i "s|ALLOW_USERS=\"|ALLOW_USERS=\"${NEWUSER}|g" /etc/snapper/configs/home
sed -i "s|ALLOW_USERS=\"|ALLOW_USERS=\"${NEWUSER}|g" /etc/snapper/configs/root
sed -i "s|ALLOW_GROUPS=\"|ALLOW_GROUPS=\"wheel|g" /etc/snapper/configs/home # Allow $NEWUSER to modify the files
sed -i "s|ALLOW_GROUPS=\"|ALLOW_GROUPS=\"wheel|g" /etc/snapper/configs/root

echo -e "... Enable ACL"
sed "s|SYNC_ACL=\"no|SYNC_ACL=\"yes|g" -i /etc/snapper/configs/home
sed "s|SYNC_ACL=\"no|SYNC_ACL=\"yes|g" -i /etc/snapper/configs/root

echo -e "... Change Timeline limit for snapshot retention"
# update snap config for home directory
sed  -i "s|TIMELINE_MIN_AGE=\"3600\"|TIMELINE_MIN_AGE=\"1800\"|g"         /etc/snapper/configs/home
sed  -i "s|TIMELINE_LIMIT_HOURLY=\"10\"|TIMELINE_LIMIT_HOURLY=\"96\"|g"   /etc/snapper/configs/home  # keep hourly backup for 48 hours
sed  -i "s|TIMELINE_LIMIT_DAILY=\"10\"|TIMELINE_LIMIT_DAILY=\"14\"|g"     /etc/snapper/configs/home  # keep daily backup for 14 days
sed  -i "s|TIMELINE_LIMIT_WEEKLY=\"0\"|TIMELINE_LIMIT_WEEKLY=\"3\"|g"     /etc/snapper/configs/home  # keep weekly backup for 4 weeks
sed  -i "s|TIMELINE_LIMIT_MONTHLY=\"10\"|TIMELINE_LIMIT_MONTHLY=\"12\"|g" /etc/snapper/configs/home  # keep monthly backup for 12 months
sed  -i "s|TIMELINE_LIMIT_YEARLY=\"10\"|TIMELINE_LIMIT_YEARLY=\"5\"|g"     /etc/snapper/configs/home  # keep yearly backup for 5 years
# update snap config for root directory
sed  -i "s|TIMELINE_MIN_AGE=\"3600\"|TIMELINE_MIN_AGE=\"0\"|g"         /etc/snapper/configs/root  # Allow all snapshots to be removed, independantly of age
sed  -i "s|TIMELINE_LIMIT_HOURLY=\"1\"|TIMELINE_LIMIT_HOURLY=\"12\"|g"   /etc/snapper/configs/root  # keep hourly backup for 4 hours
sed  -i "s|TIMELINE_LIMIT_DAILY=\"4\"|TIMELINE_LIMIT_DAILY=\"7\"|g"     /etc/snapper/configs/root  # keep daily backup for 7 days
sed  -i "s|TIMELINE_LIMIT_WEEKLY=\"0\"|TIMELINE_LIMIT_WEEKLY=\"0\"|g"     /etc/snapper/configs/root  # keep weekly backup for 4 weeks
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


# Image format
# qt6-imageformats ffmpegthumbs lzop kdegraphics-thumbnailers kimageformats raw-thumbnailer kio-gdrive libappimage rawtherapee

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
# echo "KWallet login"
# echo "auth            optional        pam_kwallet5.so" >> /etc/pam.d/sddm
# echo "session         optional        pam_kwallet5.so auto_start" >> /etc/pam.d/sddm


# # IF pass git is required, install pass-git
# sudo -u megavolts yay -S --noconfirm pass-git


# # FIX user permssion in folder
# find ~ \! -uid `id -u` -o \! -gid `id -g`
