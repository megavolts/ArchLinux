DRIVE=/dev/sda

gdisk /dev/sda
2 +8G 		8200	SWAP
1 all		8300	SArch


# Format and mount partitions
mkswap -L swap /dev/sda2
swapon /dev/sda2

mkfs.btrfs --force --label system /dev/sda1
mount -o defaults,relatime,discard,ssd,nodev,nosuid /dev/sda1 /mnt/

# Create the subvolumes
mkdir -p /mnt/_snapshot
mkdir -p /mnt/_active
btrfs subvolume create /mnt/_active/root
btrfs subvolume create /mnt/_active/home

# Mount subvolumes
mount -o defaults,relatime,ssd,nodev,subvol=_current/root /dev/sda1 /mnt
mkdir -p /mnt/home 	
mount -o defaults,relatime,ssd,nodev,nosuid,subvol=_current/home /dev/sda1 /mnt/home

# Install Arch Linux
pacstrap /mnt base
genfstab -U -p /mnt>> /mnt/etc/fstab
#hange swap dir: /dev/sda1
# Add arch_root: LABEL=ArchLinux       /mnt/btrfs-arch               btrfs           rw,nodev,relatime,ssd,discard,space_cache

arch-chroot /mnt/btrfs-current
pacman -S btrfs-progs zsh grub-bios


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

