#/bin/bash!
# specific config for X220

# echo -e ".. creating service file for initramfs regeneration"
# wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/X220/source/initramfs-update.path -O /etc/systemd/system/initramfs-update.path
# wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/X220/source/initramfs-update.service -O /etc/systemd/system/initramfs-update.service
# mkdir /opt/megavolts/
# mkdir /boot/efi
# wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/X220/source/copy_efistub.sh -O /opt/megavolts/copy_efistub.sh
# chmod +x /opt/megavolts/copy_efistub.sh
# systemctl enable initramfs-update.path

## Graphical interface
echo -e ".. install drivers specific to X220"
pacman -S --noconfirm mesa lib32-mesa vulkan-intel lib32-vulkan-intel mesa-vdpau

## wireless driver
pacman -S --noconfirm linux-firmware

# add btrfs hook and remove fsck
sed -i 's/fsck)/btrfs)/g' /etc/mkinitcpio.conf

echo -e "... rebuilding initramfs with i915"
echo "options i915"
mkinitcpio -p linux-zen

## BOOTLOADER

echo -e ".. install bootloader"
pacman -Sy refind intel-ucode --noconfirm
refind-install
# change root_dev for its uuid
# wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/X220/source/refind.conf -O /boot/EFI/refind/refind.conf
# echo "also_scan_dirs +,_active/@root/boot" >> /boot/EFI/refind/refind.conf
# sed 's/\(.*\)"/\1\ rw rootflags=subvol=_active\/\@root\"/' -i /boot/refind_linux.conf 
# pacman -Sy --noconfirm intel-ucode 
# sed 's/\(.*\)"/\1\ initrd=\/intel-ucode.img\"/' -i /boot/refind_linux.conf 
# OR
# sed -i "s|ROOT_UUID|$(blkid -o value -s UUID /dev/$root_dev)|" /boot/EFI/refind/refind.conf
wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/T14/source/refind_linux.conf -O /boot/EFI/refind/refind_linux.conf

echo -e ".. Install xorg and input"
pacman -S --noconfirm xorg-server xorg-apps xorg-xinit xorg-xrandr xorg-xkill

echo -e "... install plasma windows manager"
pacman -S --noconfirm plasma-desktop sddm networkmanager  plasma-nm kscreen powerdevil

echo -e ".. install audio server"
pacman -S --noconfirm alsa-utils pulseaudio pulseaudio-alsa pulseaudio-jack pulseaudio-equalizerplasma-pa pavucontrol pulseaudio-zeroconf 

echo -e ".. Installing bluetooth"
yaourtpkg "bluez bluez-utils pulseaudio-bluetooth"
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
systemctl enable bluetooth

echo -e ".. disable kwallet for users"
tee /home/${USER}/.config/kwalletrc <<EOF
[Wallet]
Enabled=false
EOF

echo -e "... configure sddm"
pacman -S sddm --noconfirm
sddm --example-config > /etc/sddm.conf
sed -i 's/Current=/Current=breeze/' /etc/sddm.conf
sed -i 's/CursorTheme=/CursorTheme=breeze_cursors/' /etc/sddm.conf
systemctl enable sddm

# # Mount or format data tank:
mkdir /mnt/btrfs-arch

mount -o defaults,compress=lzo,noatime,nodev,ssd,discard /dev/mapper/arch /mnt/btrfs-arch
btrfs subvolume create /mnt/btrfs-arch/@data
btrfs subvolume create /mnt/btrfs-arch/@media
btrfs subvolume create /mnt/btrfs-arch/@anarchy
btrfs subvolume create /mnt/btrfs-arch/@photography
btrfs subvolume create /mnt/btrfs-arch/@UAF-data
umount /mnt


echo "\n# BTRFS volume"  >> /etc/fstab
echo "LABEL=tank  /mnt/data btrfs rw,nodev,noatime,ssd,discard,compress=lzo,space_cache,noauto 0 0" >> /etc/fstab

echo "# Data TANK subvolume"  >> /etc/fstab
mkdir -p /mnt/data
echo "LABEL=tank	/mnt/data				btrfs	rw,nodev,noatime,compress=lzo,ssd,discard,space_cache,subvol=@data	0	0" >> /etc/fstab
mkdir -p /mnt/data/media
echo "LABEL=tank	/mnt/data/media			btrfs	rw,nodev,noatime,compress=lzo,ssd,discard,space_cache,subvol=@media	0	0" >> /etc/fstab
mkdir -p /mnt/data/anarchy
echo "LABEL=tank	/mnt/data/anarchy		btrfs	rw,nodev,noatime,compress=lzo,ssd,discard,space_cache,subvol=@anarchy	0	0" >> /etc/fstab
mkdir -p /mnt/data/UAF-data
echo "LABEL=tank	/mnt/data/UAF-data		btrfs	rw,nodev,noatime,compress=lzo,ssd,discard,space_cache,subvol=@UAF-data	0	0" >> /etc/fstab
mkdir -p /mnt/data/media/photography     
echo "LABEL=tank	/mnt/data/media/photography		btrfs	rw,nodev,noatime,compress=lzo,ssd,discard,space_cache,subvol=@photography	0	0" >> /etc/fstab

mount -a

# # set VBox directoy with nocow
# chattr +C /mnt/data/VBox

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


if [ -f /boot/vmlinuz-linux ]; then
	mkinitcpio -p linux
fi
if [ -f /boot/vmlinuz-linux-zen ]; then
	mkinitcpio -p linux-zen
fi

exit
