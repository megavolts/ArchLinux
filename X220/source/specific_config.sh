#/bin/bash!
# specific config for X220
root_dev=$1
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
mkdir /boot/EFI/zen
cp /boot/vmlinuz-linux-zen /boot/EFI/zen/vmlinuz-zen.efi
cp /boot/initramfs-linux-zen.img /boot/EFI/zen/archlinux-zen.img

echo -e ".. install bootloader"
pacman -Sy refind-efi --noconfirm
refind-install
# change root_dev for its uuid
wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/X220/source/refind.conf -O /boot/EFI/refind/refind.conf
sed -i "s|ROOT_UUID|$(blkid -o value -s UUID /dev/$root_dev)|" /boot/EFI/refind/refind.conf

# create a cryptab entry
mv /home.keyfile /etc/home.keyfile
echo "home /dev/sdb5 /etc/home.keyfile" >> /etc/crypttab
# for part uuid
#home_uuid=$(blkid -o value -s UUID /dev/$home_dev)
#echo "home UUID="$home_uuid" /etc/home.keyfile" 

echo ".. updating kernel image in /boot"
cp /boot/vmlinuz-linux-zen /boot/EFI/zen/vmlinuz-zen.efi
cp /boot/initramfs-linux-zen.img /boot/EFI/zen/archlinux-zen.img

exit
