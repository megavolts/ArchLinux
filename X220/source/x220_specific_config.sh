#/bin/bash!
# specific config for X220
root_dev=$1
home_dev=$2

echo -e ".. set hostname to adak"
echo adak > /etc/hostname

echo -e ".. generating initramfs"
wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/X220/source/mkinitcpio.conf -O /etc/mkinitcpio.conf
mkinitcpio -p linux-zen

echo -e ".. creating service file for initramfs regeneration"
wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/X220/source/initramfs-update.path -O /etc/systemd/system/initramfs-update.path
wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/X220/source/initramfs-update.service -O /etc/systemd/system/initramfs-update.service
systemctl enable initramfs-update.path

echo -e ".. config bootloader"
# copy vmlinuz and initramfs
mkdir /boot/EFI/zen
cp /boot/vmlinuz-linux-zen /boot/EFI/zen/vmlinuz-zen.efi
cp /boot/initramfs-linux-zen.img /boot/EFI/zen/archlinux-zen.img

wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/X220/source/refind.conf -O /boot/EFI/refind/refind.conf
sed -i "s|ROOT_UUID|$(blkid -o value -s UUID /dev/$root_dev)|" /boot/EFI/refind/refind.conf

pacman -Sy refind-efi --noconfirm
refind-install

# create a cryptab entry
mv /home.keyfile /etc/home.keyfile
echo "home /dev/sdb5 /etc/home.keyfile" >> /etc/crypttab

echo ".. updating kernel image in /boot"
cp /boot/vmlinuz-linux-zen /boot/EFI/zen/vmlinuz-zen.efi
cp /boot/initramfs-linux-zen.img /boot/EFI/zen/archlinux-zen.img
rm software_install.sh
rm /config_archlinux.sh
exit


## Function
get_uuid() {
    blkid -o export "$1" | grep UUID | awk -F= '{print $2}'
}
