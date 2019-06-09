DRIVE1=/dev/sda
DRIVE2=/dev/sdb
USER=megavolts
PASSWORD=F1n1ster3

sgdisk --zap-all $DRIVE1
sgdisk --zap-all $DRIVE2

echo "label: dos
label-id: 0x78e4d41b
device: /dev/sda
unit: sectors

/dev/sda1 : start=        2048, size=     1048576, type=83
/dev/sda2 : start=     1050624, size=    33554432, type=82
/dev/sda3 : start=    34605056, size=  1918920112, type=83
" >> part_layout.sfdisk

sfdisk $DRIVE1 < part_layout.sfdisk
sfdisk $DRIVE2 < part_layout.sfdisk

# Format
mkswap ${DRIVE1}2 -L swap
mkswap ${DRIVE2}2 -L swap-mirror
swapon -L swap
swapon -L swap-mirror

mkfs.btrfs --force --label boot -m raid1 -d raid1 ${DRIVE1}1 ${DRIVE2}1
mkfs.btrfs --force --label arch -m raid1 -d raid1 ${DRIVE1}3 ${DRIVE2}3

# Create the subvolumes on arch
mount -o defaults,compress=lzo,relatime,nodev,nosuid /dev/disk/by-label/arch /mnt/
mkdir -p /mnt/_snapshot
mkdir -p /mnt/_active
btrfs subvolume create /mnt/_active/root
btrfs subvolume create /mnt/_active/home
umount /mnt

# Create the subvolumes on boot
mount -o defaults,relatime,nodev,nosuid /dev/disk/by-label/boot /mnt/
mkdir -p /mnt/_snapshot
mkdir -p /mnt/_active
btrfs subvolume create /mnt/_active/boot
umount /mnt

# Mount subvolumes
mount -o defaults,compress=lzo,relatime,nodev,subvol=_active/root /dev/disk/by-label/arch /mnt
mkdir -p /mnt/home
mount -o defaults,compress=lzo,relatime,nodev,subvol=_active/home /dev/disk/by-label/arch /mnt/home
mkdir -p /mnt/boot
mount -o defaults,relatime,nodev,subvol=_active/boot /dev/disk/by-label/boot /mnt/boot

# Install Arch Linux
pacstrap /mnt base base-devel
genfstab -L -p /mnt >> /mnt/etc/fstab

# add mount point for btrfs partiton
mkdir /mnt/mnt/{btrfs-root/,btrfs-boot}
echo "LABEL=arch	/mnt/btrfs-root	btrfs	rw,nodev,relatime,compress=lzo,space_cache" >> /mnt/etc/fstab
echo "LABEL=boot	/mnt/btrfs-boot	btrfs	rw,nodev,relatime,compress=lzo,space_cache" >> /mnt/etc/fstab

arch-chroot /mnt/

# add btrfs hook and remove fsck
sed -i 's/fsck)/btrfs)/g' /etc/mkinitcpio.conf 

echo -e "Entering chroot"
echo -e "..adding multilib"
sed -i 's|#[multilib]|[multilib]|' /etc/pacman.conf
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
echo -e ".. update pacman and system "
pacman -Syy
pacman -S --noconfirm archlinux-keyring
pacman-key --init
pacman-key --populate archlinux
pacman -Syu --noconfirm 

pacman -S --noconfirm btrfs-progs grub-btrfs grml-zsh-config wget
grub-install --target=i386-pc --recheck $DRIVE1
grub-install --target=i386-pc --recheck $DRIVE2
grub-mkconfig -o /boot/grub/grub.cfg --no-floppy


echo -e ".. enabling sshd"
pacman -S --noconfirm openssh 
systemctl enable sshd

echo -e ".. changing root password"
passwd  <<EOF 
$PASSWORD
$PASSWORD
EOF

# Create secondary user, e.g. megavolts
echo -e ".. create user megavolts with default password"
useradd -m -g users -G wheel,audio,disk,lp,network -s /bin/zsh megavolts
passwd megavolts << EOF
$PASSWORD
$PASSWORD
EOF

sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers

echo -e ".. change locales"
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
localectl set-locale LANG=en_US.UTF-8

echo -e ".. set timezone to America/Anchorage"
timedatectl set-ntp 1
timedatectl set-timezone America/Anchorage

echo -e ".. setting hostname & network manager"
hostnamectl set-hostname atka
echo "127.0.1.1    atka.localdomain    atka" >> /etc/hosts
pacman -Sy --noconfirm networkmanager
systemctl enable NetworkManager

# create a fake builduser
buildpkg(){
CURRENT_DIR=$pwd
PACKAGE=$1
wget https://aur.archlinux.org/cgit/aur.git/snapshot/$PACKAGE.tar.gz
tar -xvzf $PACKAGE.tar.gz -C /home/$USER
chown ${USER}:users /home/$USER/$PACKAGE -R
cd /home/${USER}/${PACKAGE}
sudo -u $USER bash -c "makepkg -si --noconfirm"
cd $CURRENT_dir 
rm /home/$USER/$PACKAGE -R
rm /home/$USER/$1.tar.gz
}

buildpkg package-query
buildpkg yaourt

yaourtpkg() {
sudo -u $USER bash -c "yaourt -S --noconfirm $1"
}

echo -e ".. Configure pacman"
yaourtpkg reflector

pacman --latest 200 --protocol http --protocol https --sort rate --save /etc/pacman.d/mirrorlist
wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/X220/source/mirrorupgrade.hook -P /etc/pacman.d/hooks

yaourt -S --noconfirm mlocate rsync 
updatedb

# change shell
chsh -s $(which zsh)
sudo -u $USER bash -c "chsh -s $(which zsh)"

echo "Umount and reboot"
exit
umount /mnt/{home,boot,}
reboot
