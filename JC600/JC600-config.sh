#/bin/bash!
# specific config for JC600
echo -e ".. install video drivers specific to JC600"
pacman -S --noconfirm xf86-video-nouveau mesa lib32-mesa

# keyboard and mouse input
pacman -S --noconfirm xf86-input-keyboard xf86-input-mouse

echo -e ".. install bootloader"
pacman -Sy grub--noconfirm
grub-install --target=i386-pc $1
# Configure grub
wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/JC600/source/mkinitcpio.conf -O /etc/mkinitcpio.conf
grub-mkconfig -o /boot/grub/grub.cfg

# Change hostname
echo -e ".. set hostname to ulva"
#hostnamectl set-hostname ulva
echo ulva > /etc/hostname

# Regenerate boot img
echo -e ".. generating initramfs"
wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/JC600/source/mkinitcpio.conf -O /etc/mkinitcpio.conf
mkinitcpio -p linux-zen
