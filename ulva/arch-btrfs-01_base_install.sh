DISK1=/dev/sda
DISK2=/dev/sdb
USER=megavolts
PASSWORD=F1n1ster3

sgdisk --zap-all $DISK1
sgdisk --zap-all $DISK2

echo "label: gpt
unit: sectors
first-lba: 34
last-lba: 234441614
start=        2048, size=     1048576, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, name=\"EFI System\"
start=     1050624, size=     8388608, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name=\"SWAP\"
start=     9439232, size=   225002383, type=0657FD6D-A4AB-43C4-84E5-0933C84B4F4F, name=\"SYSTEM\""> part_layout.sfdisk
sfdisk $DISK1 < part_layout.sfdisk
echo "label: gpt
unit: sectors
first-lba: 34
last-lba: 234441614
start=        2048, size=     1048576, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, name=\"EFI_MIRROR\"
start=     1050624, size=     8388608, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name=\"SWAP_MIRROR\"
start=     9439232, size=   225002383, type=0657FD6D-A4AB-43C4-84E5-0933C84B4F4F, name=\"SYSTEM_MIRROR\""> part_layout.sfdisk
sfdisk $DISK2 < part_layout.sfdisk

# Format and mount partitions
mkswap -L swap ${DISK1}1
swapon -L swap
mkswap -L swap_mirror ${DISK2}1
swapon -L swap_mirror

mkfs.btrfs --force --label arch -m raid1 -d raid1 ${DISK1}3 ${DISK2}3

# Create the subvolumes on arch
mount -o defaults,compress=lzo,relatime,nodev,nosuid /dev/disk/by-label/arch /mnt/
mkdir -p /mnt/_snapshot
mkdir -p /mnt/_active
btrfs subvolume create /mnt/_active/@root
btrfs subvolume create /mnt/_active/@home
umount /mnt

# Create the subvolumes on boot:
mkfs.vfat -F32 ${DISK1}1

# Mount subvolume
mount -o defaults,compress=lzo,relatime,nodev,subvol=_active/@root /dev/disk/by-label/arch /mnt
mkdir -p /mnt/home
mount -o defaults,compress=lzo,relatime,nodev,subvol=_active/@home /dev/disk/by-label/arch /mnt/home


# Install Arch Linux
pacstrap /mnt base base-devel
genfstab -L -p /mnt>> /mnt/etc/fstab
echo "# arch root btrfs volume" >> /mnt/etc/fstab
echo "LABEL=arch  /mnt/btrfs-arch btrfs rw,nodev,relatime,ssd,discard,compress=lzo,space_cache" >> /mnt/etc/fstab

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
grub-install --target=i386-pc --recheck $DISK1
grub-install --target=i386-pc --recheck $DISK2
grub-mkconfig -o /boot/grub/grub.cfg


### OTHER

echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
localectl set-locale LANG=en_US.UTF-8

timedatectl set-ntp 1
timedatectl set-timezone America/Anchorage

hostnamectl set-hostname ulva
echo "127.0.1.1	ulva.localdomain	ulva" >> /etc/hosts

passwd  <<EOF 
$PASSWORD
$PASSWORD
EOF

grub-install --target=i386-pc --recheck /dev/sda
nano /etc/default/grub
 * Edit settings (e.g., disable gfx, quiet, etc.)
grub-mkconfig -o /boot/grub/grub.cfg

== Unmount and reboot ==

exit

umount /mnt/home
umount /mnt

reboot

