#/bin/bash!
PASSWORD=$1
echo -e "Entering chroot"
echo -e "Tuning pacman"

echo -e "..adding multilib"
sed -i 's|#[multilib]|[multilib]|' /etc/pacman.conf
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
echo -e ".. update pacman and system "
pacman -Syy
pacman -S archlinux-keyring
pacman-key --init
pacman-key --populate archlinux
pacman -Syu

echo -e ".. change locales"
echo "FONT=lat9w-16" >> /etc/vconsole.conf
wget https://raw.githubusercontent.com/megavolts/X220/master/source/locale.gen -O /etc/locale.gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
locale-gen
export LANG=en_US.UTF-8

echo -e ".. set timezone to America/Anchorage"
rm /etc/localtime
ln -sf /usr/share/zoneinfo/America/Anchorage /etc/localtime
hwclock --systohc --utc

echo -e ".. set hostname to adak"
echo adak > /etc/hostname

echo -e ".. generating initramfs"
wget https://raw.githubusercontent.com/megavolts/ArchLinux/X220/master/source/mkinitcpio.conf -O /etc/mkinitcpio.conf
mkinitcpio -p linux-zen

echo -e ".. creating service file for initramfs regeneration"
wget https://raw.githubusercontent.com/megavolts/ArchLinux/X220/master/source/initramfs-update.path -O /etc/systemd/system/initramfs-update.path
wget https://raw.githubusercontent.com/megavolts/ArchLinux/X220/master/source/initramfs-update.service -O /etc/systemd/system/initramfs-update.service
systemctl enable initramfs-update.path

echo -e ".. setting root password"
passwd root << EOF
$PASSWORD
$PASSWORD
EOF

echo -e ".. install bootload:
# copy vmlinuz and initramfs
mkdir /boot/EFI/zen
cp /boot/vmlinuz-linux-zen /boot/EFI/zen/vmlinuz-zen.efi
cp /boot/initramfs-linux-zen.img /boot/EFI/zen/archlinux-zen.img
*wget /backup/refindo.conf -O /boot/EFI/refind/refind.conf*
# change /dev/sdb4 with uuid

pacman -S refind-efi --noconfirm
refind-install
# create a cryptab entry
mv /home.keyfile /etc/home.keyfile
echo "home /dev/sdb5 /etc/home.keyfile" >> /etc/crypttab

echo -e ".. create user megavolts with default password"
useradd -m -g users -G wheel,audio,disk,lp,network -s /bin/bash megavolts
passwd megavolts << EOF
$PASSWORD
$PASSWORD
EOF

echo -e " ... adding megavolts to wheel 
sed 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/'

systemctl enable sshd

pacman -S mlocate rsync --noconfirm
updatedb

# crete a fake builduser
useradd builduser -m # Create the builduser
passwd -d builduser # Delete the buildusers password
echo "builduser ALL=(ALL) ALL" >> /etc/sudoers
buildpkg(){
  CURRENT_DIR=$pwd
  wget https://aur.archlinux.org/cgit/aur.git/snapshot/$1.tar.gz
  tar -xvzf $1.tar.gz -C /home/builduser
  chown builduser:builduser /home/builduser/$1 -R
  cd /home/builduser/$1
  sudo -u builduser bash -c "makepkg -si --noconfirm"
  cd $CURRENT_dir 
  rm /home/builduser/$1 -R
  rm $1.tar.gz
}

buildpkg package-query
buildpkg yaourt

yaourtpkg() {
  sudo -u builduser bash -c "yaourt -S --noconfirm $1"
}

yaourtpkg -S grml-zsh-config
chsh -s $(which zsh)
chsh -s $(which zsh) megavolts

echo -e ".. Configure pacman"
yaourtpkg reflector

reflector --latest 200 --protocol http --protocol https --sort rate --save /etc/pacman.d/mirrorlist
wget https://raw.githubusercontent.com/megavolts/ArchLinux/X220/master/source/mirrorupgrade.hook -P /etc/pacman.d/hooks/

echo -e ".. Install xorg and input"
pacman -S --noconfirm xorg-server xorg-apps xf86-video-intel mesa-libgl lib32-mesa-libgl libva-intel-driver libva xorg-xinit xorg-xrandr <<EOF
all
1
EOF
pacman -S --noconfirm xf86-input-synaptics xf86-input-keyboard xf86-input-wacom xf86-input-mouse

echo -e "... rebuilding initramfs with i915"
echo "options i915 enable_rc6=1 enable_fbc=1 lvds_downclock=1" >> /etc/modprobe.d/i915.conf
mkinitcpio -p linux-zen

echo -e "... install plasma windows manager"
pacman -S plasma-dekstop sddm networkmanager powerdevil plasma-nm kscreen --noconfirm

echo -e "... configure sddm"
sddm --example-config > /etc/sddm.conf
sed -i 's/Current=/Current=breeze/' /etc/sddm.conf
sed -i 's/CursorTheme=/CursorTheme=breeze_cursors/' /etc/sddm.conf
systemctl enable sddm

echo -e "... enable NetworkManager"
systemctl enable NetworkManager.service
systemctl start NetworkManager.service

echo -e "... set hostname to adak"
hostnamectl set-hostname adak

echo -e ".. install audio server"
yaourtpkg "alsa-utils pulseaudio pulseaudio-alsa pulseaudio-jack pulseaudio-equalizer kmix libcanberra-pulse libcanberra-gstreamer"

wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/source/software_install.sh
chmod +x software_install.sh

userdel builduser
rm /home/builduser -R

