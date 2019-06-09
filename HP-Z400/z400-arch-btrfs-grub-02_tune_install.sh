USER=megavolts
#DISK3=/dev/sdc
DISK4=/dev/sdd

yaourtpkg() {
  sudo -u $USER bash -c "yaourt -S --noconfirm $1"
}

echo "Disable PC speaker"
rmmod pcspkr
echo "blacklist pcspkr" >> /etc/modprobe.d/nobeep.conf

# create media tank
pacman -S --noconfirm gptfdisk

#sgdisk --zap-all $DISK3
#sgdisk --zap-all $DISK4

#sgdisk -n 0:0:0 -t 1:8300 -c 1:TANK-DATA $DISK3
#sgdisk -n 0:0:0 -t 1:8300 -c 1:TANK-DATA-MIRROR $DISK4
#mkfs.btrfs --force --label tank-data /dev/disk/by-partlabel/TANK-DATA-MIRROR
#mkfs.btrfs --force --label tank-data -m raid1 -draid1 /dev/disk/by-partlabel/TANK-DATA /dev/disk/by-partlabel/TANK-DATA-MIRROR

mkdir -p /mnt/btrfs-tank-data/
mount -o defaults,relatime,compress=zstd,nodev /dev/disk/by-label/tank-data /mnt/btrfs-tank-data
mkdir -p /mnt/btrfs-tank-data/_snapshot
echo "LABEL=tank-data	/mnt/btrfs-tank-data btrfs rw,nosuid,nodev,relatime,ssd,space_cache,compress=zstd	0	0" >> /etc/fstab

# data-UAF
btrfs subvolume create /mnt/btrfs-tank-data/@UAF
mkdir -p /mnt/data/UAF-data
echo "LABEL=tank-data	/mnt/data/UAF-data btrfs rw,nodev,relatime,compress=zstd,space_cache,subvol=/@UAF	0	0" >> /etc/fstab

# Access Control List:
yaourtpkg "acl"
setfacl --test -m "u:megavolts:rwx" /mnt/data/UAF-data
getfacl /mnt/data/UAF-data

# .. Install xorg and input
echo -e ".. Install xorg and input"
pacman -S --noconfirm xorg-server xorg-apps xorg-xinit xorg-xrandr xorg-xkill xf86-video-nouveau lib32-mesa lib32-libdrm libdrm mesa <<EOF
all
1
EOF
# add nouveau to the hook
sed -i 's/MODULES=(/MODULES=(nouveau/g' /etc/mkinitcpio.conf 
mkinitcpio -p linux
mkdir -p /etc/share/X11/xorg.conf.d/ 
tee /etc/share/X11/xorg.conf.d/20-nouveau.conf <<EOF
Section "Device"
    Identifier "Nvidia card"
    Driver "nouveau"
EndSection
EOF


# .. Install Desktop Manager
echo -e ".. Install KDE Desktop Environment"
yaourtpkg "plasma sddm archlinux-themes-sddm"
echo -e "... Configuring sddm logging manager"
sddm --example-config > /etc/sddm.conf
sed -i 's/Numlock=none/Numlock=on/g' /etc/sddm.conf
sed -i 's/Current=/Current=breeze/g' /etc/sddm.conf
systemctl enable sddm

echo -e ".. Installing Wake-on-Lan (WoL)"
yaourtpkg "ethtool gnu-netcat arp-scan"

echo -e "... audio server"
yaourtpkg "alsa-utils pulseaudio pulseaudio-alsa pulseaudio-jack pulseaudio-equalizer libcanberra-pulse libcanberra-gstreamer pavucontrol"

echo -e "... basic tools"
yaourtpkg "yakuake tmux kdialog kfind screen solaar"
yaourtpkg "gparted ntfs-3g exfat-utils mtools"

echo -e "... installing fonts"
yaourtpkg "ttf-dejavu font-mathematica ttf-mathtype ttf-freefont ttf-inconsolata ttf-hack ttf-anonymous-pro ttf-freefont ttf-liberation"

echo -e ".. coding tools"
packages = 'sublime-text-dev pycharm-community-edition python-pip'
packages+= ' python-numpy python-matplotlib python-scipy python-pandas python-openpyxl'
yaourtpkg packages

echo -e ".. file explorer"
yaourtpkg "dolphin dolphin-plugins qt5-imageformats ffmpegthumbs kdegraphics-thumbnailers"
yaourtpkg "ark unrar p7zip unzip"

echo -e "... viewer"
yaourtpkg "okular spectacle kdegraphics-mobipocket"


echo -e ".. Install multimedia"
yaourtpkg "plex-media-server-plexpass plex-media-player ffmpeg vlc"
systemctl start plexmediaserver
systemctl enable plexmediaserver

yaourtpkg "imagemagick guetzli geeqie libraw inkscape gimp darktable libraw hugin-hg xnviewmp-system-libs"

yaourtpkg "firefox thunderbird filezilla profile-sync-daemon telegram-desktop"
echo -e "... configure profile-sync-daemon to improve speed, reduced wear to physical drives"
echo "megavolts ALL=(ALL) NOPASSWD: /usr/bin/psd-overlay-helper" >> /etc/sudoers
mkdir -p /home/megavolts/.config/psd
wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/config/psd.conf -O /home/megavolts/.config/psd/psd.conf
systemctl --user start psd

echo -e ".. office"
yaourtpkg "libreoffice-fresh mendeleydesktop texmaker texlive-most"<<EOF
all
EOF
yaourtpkg "aspell-fr aspell-en aspell-de hunspell-en_US hunspell-fr hunspell-de hyphen-en hyphen-en hyphen-de libmythes mythes-en mythes-fr libreoffice-extension-grammalecte-fr"

echo -e "Install software"
echo -e ".. basic tools"
yaourtpkg "gnome-keyring thunar-archive-plugin thunar-media-tags-plugin ffmpegthumbnailer poppler-glib libgsf libopenraw unrar p7zip unzip ntfs-3g xorg-xkill tilda arp-scan"

yaourtpkg "nextcloud-client"

echo -e ".. printing tools"
yaourtpkg "cups"

# other isntall

yaourtpkg "synergy"

yaourtpkg "nextcloud-client qownnotes"

# Install snapper and btrbk for snapshot and backup
# snap-pac introduce hook to run snapper before and after pacman update
yaourtpkg "snapper snapper-gui-git btrbk snap-pac"
systemctl start grub-btrfs.path
systemctl enable grub-btrfs.path
# Snapper config:
snapper -c root create-config /
snapper -c home create-config /home
snapper -c boot create-config /boot

# we want the snaps located /at /mnt/btrfs-root/_snapthot rather than at the root
btrfs subvolume delete /.snapshots
btrfs subvolume delete /home/.snapshots
btrfs subvolume delete /boot/.snapshots

btrfs subvolume create /mnt/btrfs-root/_snapshot/root_snaps
btrfs subvolume create /mnt/btrfs-root/_snapshot/home_snaps
btrfs subvolume create /mnt/btrfs-boot/_snapshot/boot_snaps

# mount subvolume to original snapper subvolume
mkdir /.snapshots
mkdir /home/.snapshots
mkdir /boot/.snapshots
mount -o compress=lzo,subvol=_snapshot/home_snaps /dev/disk/by-label/arch /home/.snapshots
mount -o compress=lzo,subvol=_snapshot/root_snaps /dev/disk/by-label/arch /.snapshots
mount -o compress=lzo,subvol=_snapshot/boot_snaps /dev/disk/by-label/boot /.snapshots


echo "snapper subvolume" >> /etc/fstab
echo "LABEL=arch  /.snapshots    btrfs rw,noatime,compress=lzo,sspace_cache,subvol=_snapshot/root_snaps   0 0" >> /etc/fstab
echo "LABEL=arch  /home/.snapshots    btrfs rw,noatime,compress=lzo,sspace_cache,subvol=_snapshot/home_snaps   0 0" >> /etc/fstab
echo "LABEL=boot  /boot/.snapshots    btrfs rw,noatime,compress=lzo,sspace_cache,subvol=_snapshot/boot_snaps   0 0" >> /etc/fstab


# Allow $USER
sed -i "s/ALLOW_USERS=\"/ALLOW_USERS=\"$USER/g" /etc/snapper/configs/home
sed -i "s/ALLOW_USERS=\"/ALLOW_USERS=\"$USER/g" /etc/snapper/configs/root
sed -i "s/ALLOW_USERS=\"/ALLOW_USERS=\"$USER/g" /etc/snapper/configs/boot

systemctl start snapper-timeline.timer snapper-cleanup.timer
systemctl enable snapper-timeline.timer snapper-cleanup.timer

# do not index snapshot via mlocate
echo 'PRUNENAMES = ".snapshots"' >>/etc/updatedb.conf

# snapshots:
# backup of snapshots:
# Source: https://ramsdenj.com/2016/04/05/using-btrfs-for-easy-backup-and-rollback.html
mkdir -p /mnt/btrfs-tank-media/_snapshot/btrbk_snaps_bk
btrfs subvolume create /mnt/btrfs-tank-media/_snapshot/btrbk_snaps_bk/root
btrfs subvolume create /mnt/btrfs-tank-media/_snapshot/btrbk_snaps_bk/home


# Automate backup of boot to root for snapper
tee /etc/systemd/system/backup_root.path <<EOF
[Unit]
Description=Detect change in initramfs-linux

[Path]
PathChanged=/boot/initramfs-linux-fallback.img

[Install]
WantedBy=multi-user.target
WantedBy=system-update.target
EOF

tee //etc/systemd/system/backup_root.service << EOF
[Unit]
Description=Copy boot to boot_on_root_backup to automate backup with snapper

[Service]
Type=oneshot
ExecStart=/usr/bin/rm -R /boot_on_root_backup
ExecStart=/usr/bin/cp -af /boot/ /boot_on_root_backup
ExecStart=/usr/bin/bash -c 'echo "$(uname -r)" > /boot_on_root_backup/kernel.version'
EOF
systemctl start backup_root.path
systemctl enable backup_root.path

# TODO: WoL
echo -e "... setup wake on lan WoL"

# check if port is open
yaourt -S lsof
wol --port MAC -i IP
