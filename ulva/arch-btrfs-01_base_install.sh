DISK1=/dev/sda
DISK2=/dev/sdb
USER=megavolts
PASSWORD=F1n1ster3

sgdisk --zap-all $DISK1
sgdisk --zap-all $DISK2

sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI System" $DISK1
sgdisk -n 2:0:+4G   -t 2:8200 -c 2:"SWAP" $DISK1
sgdisk -n 3:0:0     -t 3:8300 -c 3:"SYSTEM" $DISK1
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI System_MIRROR" $DISK2
sgdisk -n 2:0:+4G   -t 2:8200 -c 2:"SWAP_MIRROR" $DISK2
sgdisk -n 3:0:0     -t 3:8300 -c 3:"SYSTEM_MIRROR" $DISK2

#https://askubuntu.com/questions/660023/how-to-install-ubuntu-14-04-16-04-64-bit-with-a-dual-boot-raid-1-partition-on-an

# Format and mount partitions
mkswap -L swap ${DISK1}2
swapon -L swap
mkswap -L swap_mirror ${DISK2}2
swapon -L swap_mirror

mkfs.btrfs --force --label arch -m raid1 -d raid1 ${DISK1}3 ${DISK2}3

mkfs.vfat -F32 ${DISK1}1
mkfs.vfat -F32 ${DISK2}1

# Create the subvolumes on arch
mount -o defaults,compress=lzo,relatime,nodev,nosuid /dev/disk/by-label/arch /mnt/
mkdir -p /mnt/_snapshot
mkdir -p /mnt/_active
btrfs subvolume create /mnt/_active/@root
btrfs subvolume create /mnt/_active/@home
umount /mnt

# Mount subvolume
mount -o defaults,compress=lzo,relatime,nodev,subvol=_active/@root /dev/disk/by-label/arch /mnt
mkdir -p /mnt/home
mount -o defaults,compress=lzo,relatime,nodev,subvol=_active/@home /dev/disk/by-label/arch /mnt/home
mkdir -p /mnt/boot
mount ${DISK1}1 /mnt/boot

# Install Arch Linux
pacstrap /mnt base base-devel
genfstab -L -p /mnt>> /mnt/etc/fstab
echo "# arch root btrfs volume" >> /mnt/etc/fstab
echo "LABEL=arch  /mnt/btrfs-arch btrfs rw,nodev,relatime,ssd,discard,compress=lzo,space_cache" >> /mnt/etc/fstab


# CHROOT
arch-chroot /mnt/

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

# add btrfs hook and remove fsck
pacman -S --noconfirm btrfs-progs grml-zsh-config refind-efi
chsh -s $(which zsh) && $(which zsh)
sed -i 's/fsck)/btrfs)/g' /etc/mkinitcpio.conf
mkinitcpio -p linux

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

# Install bootloader

#== Unmount and reboot ==
refind-install

# for btrfs add:
echo "also_scan_dirs +,_active/@root/boot" >> /boot/EFI/refind/refind.conf
sed 's/\(.*\)"/\1\ rw rootflags=subvol=_active\/\@root\"/' -i /boot/refind_linux.conf 

dd if=${DISK1}1 of=${DISK2}1
efibootmgr -c -g -d ${DISK2} -p 2 -L "X220_mirror" -l '\EFI\refind\refind_x64.efi'

exit

umount /mnt/{home,boot,}
reboot

