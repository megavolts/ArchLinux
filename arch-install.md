# Archlinux @ HPZ400

## 0. Computer Spec
### 0.1 Hard drives
2 x 1.5 To WD Green in raid for system (/dev/sda, /dev/sdc ==> /devmd126)
1 x 4 To SeaGate for storage
data storage backup @ mull in WRRB


## 1. Installation
### 1.1 prepare hard drive
#### 1.1.1 System
Prepare system drive for GRUB/GPT install
```
gdisk /dev/md126
```
Create following partition table
```
Number  Pat Type  FSType      Label     Size
1       Primary   BIOS/ef02   bios_grub 1.0 Mib
2       Primary   Linux/8300  boot      512.0 Mib
3       Primary   Linux/8300  root      200.0 Gib
4       Primary   Linux/8300  home      200.0 Gib
5       Primary   Linux/8300  data      996.8 Gib 
```

#### 1.1.2 Encrypt and mount root device with a password
```
cryptsetup -c aes-xts-plain64 -s 512 -h sha512 -i 5000 --use-random --verify-passphrase luksFormat /dev/md126p3
cryptsetup luksdump /dev/md126p3
cryptsetup luksOpen /dev/md126p3 root
```
Format root parititon
```
mkfs.ext4 /dev/mapper/root
```
Mount root partition
```
mount /dev/mapper/root /mnt
```
#### 1.1.3 Encrypt and mount home device with a file and a password
```
cryptsetup -c aes-xts-plain64 -s 512 -h sha512 -i 5000 --use-random --verify-passphrase luksFormat /dev/md126p4
cryptsetup luksdump /dev/md126p4
```
Create and add a keyfile
```
dd if=/dev/urandom of=/mnt/home.keyfile bs=512 count=4
cryptsetup luksAddKey /dev/md126p4 /mnt/home.keyfile
cryptsetup luksDump /dev/md126p4
```
Decrypt partition with keyfile
```
cryptsetup luksOpen /dev/md126p4 -d /mnt/home.keyfile home
```
Format root parititon
```
mkfs.ext4 /dev/mapper/home
```
Mount root partition
```
mkdir /mnt/home
mount /dev/mapper/home /mnt/home
```
### 1.1.4 Boot partition
```
mkfs.ext4 /dev/md126p2
mkdir -p /mnt/boot
mount /dev/md126p2 /mnt/boot
```
### 1.1.5 Swapfile
Check ram memory size
```
free
```
Create adequate size swapfile
```
fallocate -L 12G /mnt/swapfile
chmod 600 /mnt/swapfile
mkswap /mnt/swapfile
swapon /mnt/swapfile
```

## 1.2 Install base and base-devel
```
pacstrap -i /mnt base base-devel
```
Select twice default installation and proceed

## 1.3 Generate fstab, with UUID
Automatically generate fstab
```
genfstab -U /mnt >> /mnt/etc/fstab
```
Verify fstab
```
nano -w /mnt/etc/fstab
```
Corret the swapfille path, it should be
```
# Swap
/swapfile	none	swapf 	default 0 0
```

## 1.4. System configuration
chroot yourself
```
arch-chroot /mnt
```

### 1.4.0 Disable pc speaker
```
rmmod pcspkr
```

### 1.4.1 update system
Enable multilib repositories
```
nano -w /etc/pacman.conf
```
And uncomment the line
```
[multilib]
Include = /etc/pacman.d/mirrorlist
```
Update keyring
```
pacman -Syu
pacman-key --init
pacman-key --populate archlinux
pacman -Syu
```
### 1.3 Configure system
#### 1.3.1 Change console font
Add:
```
echo 'FONT=lat9-16' >> /etc/vconsole.conf
```
#### 1.3.2 Change language local
```
nano -w /etc/locale.gen
```
Uncomment for American English language
```
en_US.UTF-8 UTF-8
```
Reload and import local
```
locale-gen
export LANG=en_US.UTF-8
```
Change the timezone
#### 1.3.4 Change timezone
```
ln -s /usr/share/zoneinfo/America/Anchorage /etc/localtime
```
Sync hardware clock with utc
```
hwclock --systohc --utc
```
#### 1.3.5 Define hostname
```
echo arran > /etc/hostname
```
And modify the host file accordingly
```
nano -w /etc/hosts
```
It should looks like
```
#<ip-address> <hostname.domain.org> <hostname>
127.0.0.1 localhost.localdomain localhost arran
::1   localhost.localdomain localhost arran
```
#### 1.3.6 Modify mkinitcpio.conf and rebuild boot image
Add modules and hooks
```
nano -w /etc/mkinitcpio.conf
```
Modify the lines
```
...
modules="... ext4  raid1 ..."
hooks="... block keyboard ... encrypt resume  ... filesystems"
```
Rebuild the boot image
```
mkinitcpio -p linux
```
#### 1.3.7 Root password
```
passwd
```
And enter your root password
### 1.4 Bootloader
#### 1.4.1 Install the bootloader
Install grub package
```
pacman -S grub
```
For hardware raid, install grub on each partition /dev/sda and /dev/sdb
```
grub-install --target=i386-pc /dev/sdb
grub-install --target=i386-pc /dev/sdc
```

#### 1.4.2 If needed, modifiy grub configuration
```
nano -w /etc/default/grub
```
And finally regenerate the grub.cfg
```
grub-mkconfig -o /boot/grub/grub.cfg
```
#### 1.4.3 If needed, modifiy grub configuration
```
nano -w /boot/grub/grub.cfg
```
Modifiy for raid install

Use the following command to know the swap offset
``
filefrag -v /swapfile | awk '{if($1==0){print $3}}'
```

#### 1.3.9 Create crypttab
```
mv /home.key /etc/home.key
nano -w /etc/crypttab
```
And specify the path to the keyfile for home
```
home  /dev/md126p4 /etc/home.key
```
