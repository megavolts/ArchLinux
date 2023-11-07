#/bin/bash!
# ssh megavolts@IP

PASSWORD=$1
NEWUSER=$2
HOSTNAME=$3

echo -e ".. > Optimize mirrorlist"
pacman -S --noconfirm reflector"
systemctl enable --now reflector.timer
sed -i "s|# --country France,Germany|--country USA,Switzerland|g" /etc/xdg/reflector/reflector.conf

# Enable snapshots with snapper 
pacman -S --noconfirm snapper acl 
echo -e "... >> Configure snapper"
snapper -c root create-config /
snapper -c home create-config /home

# we want the snaps located /at /mnt/btrfs-root/_snaptshot rather than at the root
btrfs subvolume delete /.snapshots
if [ -d "/home/.snapshots" ]
then
  rmdir /home/.snapshots
fi
snapper -c home create-config /home
btrfs subvolume delete /home/.snapshots

mkdir /.snapshots
mkdir /home/.snapshots

# create btrfs snapshots subvolume
btrfs subvolume create /mnt/btrfs-arch/@snapshots
btrfs subvolume create /mnt/btrfs-arch/@snapshots/@home_snaps
btrfs subvolume create /mnt/btrfs-arch/@snapshots/@home_snaps

# add entry in fstab
echo "# Snapper subvolume" >> /etc/fstab # add snapper subvolume to fstab
echo "LABEL=arch /.snapshots btrfs rw,noatime,ssd,discard,space_cache=v2,subvol=@snapshots/@root_snaps   0 0" >> /etc/fstab
echo "LABEL=arch /home/.snapshots btrfs rw,noatime,ssd,discard,space_cache=v2,subvol=@snapshots/@home_snaps   0 0" >> /etc/fstab
systemctl daemon-relaod && mount -a

# Allow $NEWUSER and wheel group to modify files
sed "s|ALLOW_USERS=\"|ALLOW_USERS=\"$NEWUSER|g" -i /etc/snapper/configs/home
sed "s|ALLOW_USERS=\"|ALLOW_USERS=\"$NEWUSER|g" -i /etc/snapper/configs/root
sed "s|ALLOW_GROUPS=\"|ALLOW_GROUPS=\"wheel|g" -i /etc/snapper/configs/home
sed "s|ALLOW_GROUPS=\"|ALLOW_GROUPS=\"wheel|g" -i /etc/snapper/configs/root
sed "s|SYNC_ACL=\"no|SYNC_ACL=\"yes|g" -i /etc/snapper/configs/home
sed "s|SYNC_ACL=\"no|SYNC_ACL=\"yes|g" -i /etc/snapper/configs/root

# do not index snapshot via mlocate
sed 's|PRUNENAMES = "|PRUNENAMES = ".snapshots |g' -i /etc/updatedb.conf 

# Execute cleanup everyhour:
SYSTEMD_EDITOR=tee systemctl edit snapper-cleanup.timer <<EOF
[Timer]
OnUnitActiveSec=1h
EOF

# Execute snapshot every 5 minutes:
SYSTEMD_EDITOR=tee systemctl edit snapper-timeline.timer <<EOF
[Timer]
OnCalendar=*:0/5
EOF

systemctl enable --now snapper-timeline.timer snapper-cleanup.timer  # start and enable snapper 

setfacl -Rm "u:$NEWUSER:rwx" /etc/snapper/configs
setfacl -Rdm "u:$NEWUSER:rwx" /etc/snapper/configs

# update snap config for home directory
sed  "s|TIMELINE_MIN_AGE=\"1800\"|TIMELINE_MIN_AGE=\"1800\"|g" -i /etc/snapper/configs/home      # keep all backup for 2 days (172800 seconds)
sed  "s|TIMELINE_LIMIT_HOURLY=\"10\"|TIMELINE_LIMIT_HOURLY=\"96\"|g" -i /etc/snapper/configs/home  # keep hourly backup for 96 hours
sed  "s|TIMELINE_LIMIT_DAILY=\"10\"|TIMELINE_LIMIT_DAILY=\"14\"|g" -i /etc/snapper/configs/home    # keep daily backup for 14 days
sed  "s|TIMELINE_LIMIT_WEEKLY=\"0\"|TIMELINE_LIMIT_WEEKLY=\"0\"|g" -i /etc/snapper/configs/home    # do not keep weekly backup
sed  "s|TIMELINE_LIMIT_MONTHLY=\"10\"|TIMELINE_LIMIT_MONTHLY=\"12\"|g" -i /etc/snapper/configs/home # keep monthly backup for 12 months
sed  "s|TIMELINE_LIMIT_YEARLY=\"10\"|TIMELINE_LIMIT_YEARLY=\"5\"|g" -i /etc/snapper/configs/home   # keep yearly backup for 5 years

# update snap config for root directory
sed  "s|TIMELINE_MIN_AGE=\"1800\"|TIMELINE_MIN_AGE=\"1800\"|g" -i /etc/snapper/configs/root      # keep all backup for 2 days (172800 seconds)
sed  "s|TIMELINE_LIMIT_HOURLY=\"10\"|TIMELINE_LIMIT_HOURLY=\"0\"|g" -i /etc/snapper/configs/root  # keep hourly backup for 96 hours
sed  "s|TIMELINE_LIMIT_DAILY=\"10\"|TIMELINE_LIMIT_DAILY=\"14\"|g" -i /etc/snapper/configs/root    # keep daily backup for 14 days
sed  "s|TIMELINE_LIMIT_WEEKLY=\"0\"|TIMELINE_LIMIT_WEEKLY=\"8\"|g" -i /etc/snapper/configs/root    # keep weekly backup for 8 wek
sed  "s|TIMELINE_LIMIT_MONTHLY=\"10\"|TIMELINE_LIMIT_MONTHLY=\"12\"|g" -i /etc/snapper/configs/root # keep monthly backup for 12 months
sed  "s|TIMELINE_LIMIT_YEARLY=\"10\"|TIMELINE_LIMIT_YEARLY=\"5\"|g" -i /etc/snapper/configs/root   # keep yearly backup for 5 years

# enable snapshot at boot
systemctl enable snapper-boot.timer

# Copy partition on kernel update to enable backup
cat <<EOF | tee -a /usr/share/libalpm/hooks/50_bootbackup.hook
[Trigger]
Operation = Upgrade
Operation = Install
Operation = Remove
Type = Path
Target = usr/lib/modules/*/vmlinuz

[Action]
Depends = rsync
Description = Backing up /boot...
When = PostTransaction
Exec = /usr/bin/rsync -a --delete /boot /.bootbackup
EOF
mkdir /.bootbackup

# enable snapshot before and after install
pacman -S --noconfirm snap-pac

# Enable fstrim for ssd
systemctl enable --now fstrim.timer

# Enable btrfs autodefrag and btrfs maintenance after pacman update
cat <<EOF | tee -a /usr/share/libalpm/hooks/zz-snap-pac-00-btrfs_maintenance.hook
# triggered before snap-pac

[Trigger]
Operation = Upgrade
Operation = Install
Operation = Remove
Type = Package
Target = *

[Action]
Description = Performing btrfs maintenace before snapper post snapshots
Depends = snap-pac
When = PostTransaction
Exec = /opt/megavolts/btrfs_maintenance.sh
EOF

cat << EOF | tee -a /opt/megavolts/btrfs_maintenance.sh
/usr/bin/btrfs balance start -dusage=10 -dlimit=2..20 -musage=10 -mlimit=2..20 /
/usr/bin/btrfs balance start -dusage=25 -dlimit=2..10 -musage=25 -mlimit=2..10 /
/usr/bin/btrfs scrub start /
/usr/bin/btrfs scrub status -d /
/usr/bin/btrfs filesystem defragment -r /
EOF

sudo chmod +x /opt/megavolts/btrfs_maintenance.sh


## Graphical interface
echo -e ".. install drivers specific to X1 with Iris"
yay -S --noconfirm mesa vulkan-intel vulkan-mesa-layers

echo -e ".. Install xorg and input"
yay -S --noconfirm xorg-server xorg-apps xorg-xinit xorg-xrandr xorg-xkill xorg-xauth

echo -e "... install plasma windows manager"
yay -S --noconfirm plasma-desktop plasma-nm kscreen powerdevil plasma-wayland-session plasma-thunderbolt ttf-droid phonon-qt5-gstreamer packagekit-qt5  xdg-desktop-portal xdg-desktop-portal-kde

yay -S --noconfirm sddm-git snapper-gui-git

echo -e ".. install audio server"
yay -S --noconfirm pipewire lib32-pipewire pipewire-docs qpwgraph pipewire-alsa piepwire pipewire-jack plasma-pa
systemctl enable --user --now pipewire
systemctl enable --user --now pipewire-pulse

echo -e ".. Installing bluetooth"
yay -S --noconfirm bluez bluez-utils bluedevil
sudo systemctl enable --now bluetooth
yay -S duperemove

# echo -e ".. tablet tools"
yay -S --noconfirm input-wacom-dkms xf86-input-wacom  iio-sensor-proxy maliit-keyboard  kded-rotation-git detect-tablet-mode-git
# Is this necessary
echo "[General]" >> /etc/sddm.conf.d/virtualkbd.conf
echo "InputMethod=qtvirtualkeyboard" >> /etc/sddm.conf.d/virtualkbd.conf

# #echo "GTK_USE_PORTAL=1" >> /etc/environment
# Add french and emoji
gsettings set org.maliit.keyboard.maliit enabled-languages "['en', 'fr-ch', 'emoji']"
# Set up to breeze dark
echo "export QT_QUICK_CONTROLS_STYLE=org.kde.desktop && /usr/bin/maliit-keyboard" >> /opt/megavolts/maliit_theme
chmod +x /opt/megavolts/maliit_theme
cp /usr/share/applications/com.github.maliit.keyboard.desktop >> /opt/megavolts/com.github.maliit.keyboard.desktop
sed "s|maliit-keyboard|/opt/megavolts/maliit_theme|g" -i /opt/megavolts/com.github.maliit.keyboard.desktop
sed "s|/usr/share/applications/com.github.maliit.keyboard.desktop|/opt/megavolts/com.github.maliit.keyboard.desktop|g" -i .config/kwinrc
yay -S --noconfirm kded-rotation-git 

### MOUNT OTHER TO FSTAB
if [ !  -e /mnt/btrfs-arch/@media ]
then
  btrfs subvolume create /mnt/btrfs-arch/@media 
fi
if [ !  -e /mnt/btrfs-arch/@UAF-data ]
then
  btrfs subvolume create /mnt/btrfs-arch/@UAF-data
fi


sudo yay -S rmlint shredder-rmlint

echo "# BTRFS volume"  >> /etc/fstab
mkdir -p /mnt/data/media
echo "LABEL=arch  /mnt/data/media			btrfs	rw,nodev,noatime,compress=lzo,ssd,discard,space_cache,subvol=@media	0	0" >> /etc/fstab
mkdir -p /mnt/data/UAF-data
echo "LABEL=arch	/mnt/data/UAF-data		btrfs	rw,nodev,noatime,compress=lzo,ssd,discard,space_cache,subvol=@UAF-data	0	0" >> /etc/fstab
systemctl daemon-reload && mount -a

setfacl -m u:${NEWUSER}:rwx -R /mnt/data/
setfacl -m u:${NEWUSER}:rwx -Rd /mnt/data/

# 