#/bin/bash!
# ssh megavolts@IP

PWD=$1
USER=$2
HOSTNAME=$3

chsh -s $(which zsh)

echo $PWD | sudo -S -v
sudo su

echo -e ".. > Optimize mirrorlist"
yay -Sy --noconfirm reflector
reflector --latest 20 --protocol http --protocol https --sort rate --save /etc/pacman.d/mirrorlist

pacman -Sy --noconfirm mlocate
updatedb

# Enable snapshots with snapper 
yay -Sy --noconfirm snapper acl snapper-gui
echo -e "... >> Configure snapper"
snapper -c root create-config /
snapper -c home create-config /home


# we want the snaps located /at /mnt/btrfs-root/_snaptshot rather than at the root
btrfs subvolume delete /.snapshots
btrfs subvolume delete /home/.snapshots

mount /dev/mapper/arch /mnt/btrfs-arch
btrfs subvolume create /mnt/btrfs-arch/@snapshots/@root_snaps
btrfs subvolume create /mnt/btrfs-arch/@snapshots/@home_snaps

mkdir /.snapshots
mkdir /home/.snapshots
mount -o compress=lzo,subvol=@snapshots/@root_snaps /dev/mapper/arch /.snapshots
mount -o compress=lzo,subvol=@snapshots/@home_snaps /dev/mapper/arch /home/.snapshots

# Add entry in fstab
# echo "# Snapper subvolume" >> /etc/fstab # add snapper subvolume to fstab
echo "LABEL=arch /.snapshots btrfs rw,noatime,ssd,discard,compress=lzo,space_cache,subvol=@snapshots/@root_snaps   0 0" >> /etc/fstab
echo "LABEL=arch /home/.snapshots  btrfs rw,noatime,ssd,discardcompress=lzo,space_cache,subvol=@snapshots/@home_snaps   0 0" >> /etc/fstab

# echo "# Snapper subvolume" >> /etc/fstab # add snapper subvolume to fstab


sed -i "s/ALLOW_USERS=\"/ALLOW_USERS=\"$USER/g" /etc/snapper/configs/home # Allow $USER to modify the files
sed -i "s/ALLOW_USERS=\"/ALLOW_USERS=\"$USER/g" /etc/snapper/configs/root
sed 's/PRUNENAMES = "/PRUNENAMES = ".snapshots /g' -i /etc/updatedb.conf # do not index snapshot via mlocate

systemctl start snapper-timeline.timer snapper-cleanup.timer  # start and enable snapper
systemctl enable snapper-timeline.timer snapper-cleanup.timer
# Execute cleanup everyhour:
sed -i "s/OnUnitActiveSec=1d/OnUnitActiveSec=1h/g"  /etc/systemd/system/timers.target.wants/snapper-cleanup.timer
sed -i "s/OnCalendar=hourly/OnCalendar=*:0\/5/g"  /usr/lib/systemd/system/snapper-timeline.timer
setfacl -Rm "u:megavolts:rw" /etc/snapper/configs
setfacl -Rdm "u:megavolts:rw" /etc/snapper/configs

# update snap config for home directory
sed  "s|TIMELINE_MIN_AGE=\"1800\"|TIMELINE_MIN_AGE=\"1800\"|g" -i /etc/snapper/configs/home      # keep all backup for 2 days (172800 seconds)
sed  "s|TIMELINE_LIMIT_HOURLY=\"10\"|TIMELINE_LIMIT_HOURLY=\"96\"|g" -i /etc/snapper/configs/home  # keep hourly backup for 96 hours
sed  "s|TIMELINE_LIMIT_DAILY=\"10\"|TIMELINE_LIMIT_DAILY=\"14\"|g" -i /etc/snapper/configs/home    # keep daily backup for 14 days
sed  "s|TIMELINE_LIMIT_WEEKLY=\"0\"|TIMELINE_LIMIT_WEEKLY=\"0\"|g" -i /etc/snapper/configs/home    # do not keep weekly backup
sed  "s|TIMELINE_LIMIT_MONTHLY=\"10\"|TIMELINE_LIMIT_MONTHLY=\"12\"|g" -i /etc/snapper/configs/home # keep monthly backup for 12 months
sed  "s|TIMELINE_LIMIT_YEARLY=\"10\"|TIMELINE_LIMIT_YEARLY=\"5\"|g" -i /etc/snapper/configs/home   # keep yearly backup for 10 years

# enable snapshot at boot
systemctl enable snapper-boot.timer
# Copy partition on kernel update to enable backup
echo /usr/share/libalpm/hooks/50_bootbackup.hook << EOF  
[Trigger]
Operation = Upgrade
Operation = Install
Operation = Remove
Type = Package 
Target = linux* 
[Action] 
Depends = rsync 
Description = Backing up /boot... 
When = PreTransaction 
Exec = /usr/bin/rsync -a --delete /boot /.bootbackup
EOF

# enable snapshot before and after install
yay -Sy --noconfirm snap-pac rsync

## Install firmware:
## wireless driver
pacman -S --noconfirm linux-firmware
#### vvvvvvv ####

## Graphical interface
echo -e ".. install drivers specific to X1 with Iris"
pacman -S --noconfirm mesa vulkan-intel vulkan-mesa-layers

echo -e ".. Install xorg and input"
pacman -S --noconfirm xorg-server xorg-apps xorg-xinit xorg-xrandr xorg-xkill xorg-xauth

echo -e "... install plasma windows manager"
pacman -S --noconfirm plasma-desktop sddm networkmanager  plasma-nm kscreen powerdevil

echo -e "... configure sddm"
pacman -S sddm --noconfirm
sddm --example-config > /etc/sddm.conf
sed -i 's/Current=/Current=breeze/' /etc/sddm.conf
sed -i 's/CursorTheme=/CursorTheme=breeze_cursors/' /etc/sddm.conf
systemctl enable sddm

echo -e ".. install audio server"
pacman -S --noconfirm alsa-utils pulseaudio pulseaudio-alsa pulseaudio-jack pulseaudio-equalizer plasma-pa pavucontrol pulseaudio-zeroconf 

echo -e ".. Installing bluetooth"
yay -S --noconfirm bluez bluez-utils pulseaudio-bluetooth bluedevil
systemctl start bluetooth
systemctl enable bluetooth

# echo -e "... > allow streaming to bluetooth devices"
# echo "load-module module-bluetooth-policy" >> /etc/pulse/system.pa
# echo "load-module module-bluetooth-discover" >> /etc/pulse/system.pa
# sed  's/#AutoEnable=false/AutoEnable=true/g' -i /etc/bluetooth/main.conf # power on bluetooth dongle
# # add the following line to /etc/bluetooth/audio.conf to allow laptop speaker as a sink
# cat >> /etc/bluetooth/audio.conf << EOF
# [General] 
# Enable=Source
# add the following lien to /etc/pulse/default.pa to auto connect to bluetooth
# #automatically switch to newly-connected devices
# load-module module-switch-on-connect
# EOF


yay -S --noconfirm input-wacom-dkms xf86-input-wacom wacom-utility


#echo -e ".. disable kwallet for users"
#tee /home/${USER}/.config/kwalletrc <<EOF
#[Wallet]
#Enabled=false
#EOF

echo -e "... configure sddm"
pacman -S sddm --noconfirm
sddm --example-config > /etc/sddm.conf
sed -i 's/Current=/Current=breeze/' /etc/sddm.conf
sed -i 's/CursorTheme=/CursorTheme=breeze_cursors/' /etc/sddm.conf
systemctl enable sddm

# # Mount or format data tank:
mount -o defaults,compress=lzo,noatime,nodev,ssd,discard /dev/mapper/arch /mnt/btrfs-arch
btrfs subvolume create /mnt/btrfs-arch/@media
btrfs subvolume create /mnt/btrfs-arch/@photography
btrfs subvolume create /mnt/btrfs-arch/@UAF-data


echo "\n# BTRFS volume"  >> /etc/fstab
echo "LABEL=tank  /mnt/data btrfs rw,nodev,noatime,ssd,discard,compress=lzo,space_cache,noauto 0 0" >> /etc/fstab
mkdir -p /mnt/data/media
echo "LABEL=arch	/mnt/data/media			btrfs	rw,nodev,noatime,compress=lzo,ssd,discard,space_cache,subvol=@media	0	0" >> /etc/fstab
mkdir -p /mnt/data/UAF-data
echo "LABEL=arch	/mnt/data/UAF-data		btrfs	rw,nodev,noatime,compress=lzo,ssd,discard,space_cache,subvol=@UAF-data	0	0" >> /etc/fstab
mkdir -p /mnt/data/media/photography     
echo "LABEL=arch	/mnt/data/media/photography		btrfs	rw,nodev,noatime,compress=lzo,ssd,discard,space_cache,subvol=@photography	0	0" >> /etc/fstab
mount -a


# # Setup Btrbk
# yaourtpkg btrkbk mbuffer

# ## Create subvolume
# btrfs subvolume create /mnt/btrfs-tank/@snapshots
# btrfs subvolume create /mnt/btrfs-tank/@snapshots/@btrbk_root
# btrfs subvolume create /mnt/btrfs-tank/@snapshots/@btrbk_home
# btrfs subvolume create /mnt/btrfs-tank/@snapshots/@btrbk_snaps

# ## Config
# wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/X220/source/btrbk.conf -O /etc/btrbk/btrbk.conf

# ## Enable chron
# cat >> /etc/cron.daily/btrbk << EOF
# #!/bin/sh
# exec /usr/sbin/btrbk -q -c /etc/btrbk/btrbk.conf run
# EOF

# deactivate baloo indexer
# balooctl suspend
# balooctl disable

# After reboot
