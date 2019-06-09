DISK1=/dev/sda
DISK2=/dev/sdb
USER=megavolts
PASSWORD=F1n1ster3

sgdisk --zap-all $DISK1
sgdisk --zap-all $DISK2

echo "label: dos
unit: sectors
start=        2048, size=    16777216, type=82
start=    16779264, size=   217662384, type=83" > part_layout.sfdisk

sfdisk $DISK1 < part_layout.sfdisk
sfdisk $DISK2 < part_layout.sfdisk

# Format and mount partitions
mkswap -L swap ${DISK1}1
swapon -L swap
mkswap -L swap_mirror ${DISK2}1
swapon -L swap_mirror

mkfs.btrfs --force --label arch -m raid1 -d raid1 ${DISK1}2 ${DISK2}2

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


# Install Arch Linux
pacstrap /mnt base
genfstab -U -p /mnt>> /mnt/etc/fstab
#hange swap dir: /dev/sda1
# Add arch_root: LABEL=ArchLinux       /mnt/btrfs-arch               btrfs           rw,nodev,relatime,ssd,discard,space_cache

arch-chroot /mnt/btrfs-current
pacman -S btrfs-progs zsh grub-btrfs


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

