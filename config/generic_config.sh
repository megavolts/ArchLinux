#/bin/bash!
PASSWORD=$1

echo -e "Entering chroot"
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
wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/source/locale.gen -O /etc/locale.gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
locale-gen
export LANG=en_US.UTF-8

echo -e ".. set timezone to America/Anchorage"
rm /etc/localtime
ln -sf /usr/share/zoneinfo/America/Anchorage /etc/localtime
hwclock --systohc --utc

echo -e ".. setting root password"
passwd root << EOF
$PASSWORD
$PASSWORD
EOF

echo -e ".. create user megavolts with default password"
useradd -m -g users -G wheel,audio,disk,lp,network -s /bin/bash megavolts
passwd megavolts << EOF
$PASSWORD
$PASSWORD
EOF

echo -e " ... adding megavolts to wheel"
sed 's /# %wheel ALL=(ALL) ALL/%  wheel ALL=(ALL) ALL/' /etc/sudoers

systemctl enable sshd
pacman -S mlocate rsync --noconfirm
updatedb

# create a fake builduser
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

yaourtpkg -grml-zsh-config
chsh -s $(which zsh)
chsh -s $(which zsh) megavolts

echo -e ".. Configure pacman"
yaourtpkg reflector

reflector --latest 200 --protocol http --protocol https --sort rate --save /etc/pacman.d/mirrorlist
wget https://raw.githubusercontent.com/megavolts/ArchLinux/X220/master/source/mirrorupgrade.hook -P /etc/pacman.d/hooks/

echo -e "... enable NetworkManager"
systemctl enable NetworkManager.service
systemctl start NetworkManager.service

echo -e ".. install audio server"
yaourtpkg "alsa-utils pulseaudio pulseaudio-alsa pulseaudio-jack pulseaudio-equalizer libcanberra-pulse libcanberra-gstreamer "

if id userbuild >/dev/null 2>&1; then
  echo ".. deleting user userbuild"
  userdel builduser
  rm /home/builduser -R
  sed -i 's/builduser ALL=(ALL) ALL//' /etc/sudoerselse
fi

exit
