#/bin/bash!
# specific config for X220
=$1
home_dev=$2

echo -e ".. set hostname to adak"
hostnamectl set-hostname adak
echo adak > /etc/hostname

echo -e ".. generating initramfs"
wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/X220/source/mkinitcpio.conf -O /etc/mkinitcpio.conf
mkinitcpio -p linux-zen

echo -e ".. creating service file for initramfs regeneration"
wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/X220/source/initramfs-update.path -O /etc/systemd/system/initramfs-update.path
wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/X220/source/initramfs-update.service -O /etc/systemd/system/initramfs-update.service
systemctl enable initramfs-update.path

echo -e ".. install drivers specific to X220"
pacman -S --noconfirm xf86-video-intel mesa-libgl lib32-mesa-libgl libva-intel-driver libva <<EOF
all
1
EOF
pacman -S --noconfirm xf86-input-synaptics xf86-input-keyboard xf86-input-wacom xf86-input-mouse

echo -e "... rebuilding initramfs with i915"
echo "options i915 enable_rc6=1 enable_fbc=1 lvds_downclock=1" >> /etc/modprobe.d/i915.conf
mkinitcpio -p linux-zen
mkdir -p /boot/EFI/zen
cp /boot/vmlinuz-linux-zen /boot/EFI/zen/vmlinuz-zen.efi
cp /boot/initramfs-linux-zen.img /boot/EFI/zen/archlinux-zen.img

echo -e ".. install bootloader"
pacman -Sy refind-efi --noconfirm
refind-install
# change root_dev for its uuid
wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/X220/source/refind.conf -O /boot/EFI/refind/refind.conf
#sed -i "s|ROOT_UUID|$(blkid -o value -s UUID /dev/$root_dev)|" /boot/EFI/refind/refind.conf


echo -e ".. Install xorg and input"
pacman -S --noconfirm xorg-server xorg-apps xorg-xinit xorg-xrandr xorg-xkill<<EOF
all
1
EOF

echo -e "... install plasma windows manager"
pacman -S --noconfirm plasma-desktop sddm networkmanager powerdevil plasma-nm kscreen plasma-pa pavucontrol


echo -e ".. install audio server"
pacman -S --noconfirm alsa-utils pulseaudio pulseaudio-alsa pulseaudio-jack pulseaudio-equalizer libcanberra-pulse libcanberra-gstreamer

# echo -e ".. disable kwallet for users"
# tee /home/${USER}/.config/kwalletrc <<EOF
# [Wallet]
# Enabled=false
# EOF

echo -e "... configure sddm"
pacman -S sddm --noconfirm
sddm --example-config > /etc/sddm.conf
sed -i 's/Current=/Current=breeze/' /etc/sddm.conf
sed -i 's/CursorTheme=/CursorTheme=breeze_cursors/' /etc/sddm.conf
systemctl enable sddm

# GUI interface for sanpper
pacman -S snapper-gui-git '
exit
