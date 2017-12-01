# Archlinux @ Dell Precision T3400
## 0. Computer Spec
### 0.1 Hard drives
* 2 x 1.5 To WD Green 
* 1 x 4 To SeaGate
* 1 x 4 To WD Green

LVM on LUKS on RAID

## 1. Installation
### 1.1 prepare hard drive
#### 1.1.1 System
##### Wipe the disk
Wipe the entire disk
```
cryptsetup open --type plain /dev/sdXY container --key-file /dev/random
dd if=/dev/zero of=/dev/mapper/container status=progress
cryptsetup close container
```
If repurposing an previously encrypted disk, the disk header can be simply wipe.
```
head -c 1052672 /dev/urandom > /dev/sda1; sync
dd if=/dev/urandom of=/dev/sda1 bs=512 count=20480
```
##### Prepare the disk

Prepare both disk with
* 1 MiB partition for grub (gdisk code ef02)
* 931.5 GiB on the disk for raid (gdisk code fd00)

Prepare system drive for GRUB/GPT install:
```
gdisk /dev/sda
```
Create following partition table
```
Number  Pat Type  FSType            Label       Size
1       Primary   BIOS/ef02         bios_grub   1.0 Mib       
2       Linux RAID/fd00   LVM         931.3 GiB
```

Prepare system drive for GRUB/GPT install:
```
gdisk /dev/sdb
```
Create following partition table
```
Number  Pat Type  FSType            Label       Size
2      Linux RAID/fd00   LVM         931.3 GiB
```

If creating the raid array with only one disk:
```
mdadm --create --verbose --level=1 --metadata=1.2 --raid-devices=2 /dev/md0 missing/dev/sda
mdadm --create --verbose --level=1 --metadata=1.2 --raid-devices=2 /dev/md1 missing/dev/sdb
```

##### to add the second disk later
Clone the partition scheme to /dev/sdb
```
sfdisk -d /dev/sda > sda.dump
sfdisk /dev/sdb < sda.dump
```

Create the LV system
```
pvcreate --dataalignment 1m /dev/md0
pvdisplay
vgcreate vgroup /dev/md0
pvcreate --dataalignment 1m /dev/md1
vgextend vgroup /dev/md1

vgdisplay
lvcreate --size 200M --name lvboot vgroup
lvcreate --size 200G --name lvroot vgroup
lvcreate --contiguous y --size 32G --name lvswap vgroup
lvcreate --contiguous y --size 200G --name lvhome vgroup
lvcreate --extents +100%FREE --name lvdata vgroup
lvdisplay
```

Create the filesystem
```
mkfs.ext4 /dev/mapper/vgroup-lvroot
mount /dev/mapper/vgroup-lvroot /mnt
mkfs.ext4 /dev/mapper/vgroup-lvhome
mkdir /mnt/home
mount /dev/mapper/vgroup-lvrhome /mnt/home
mkfs.ext4 /dev/mapper/vgroup-lvboot
mkdir /mnt/boot
mkfs.ext4 /dev/mapper/vgroup-lvdata
mkdir /mnt/mnt/data
mount /dev/mapper/vgroup-lvdata /mnt/mnt/data
mount /dev/md0 /mnt/boot
mkswap /dev/mapper/vgroup-lvswap
swapon /dev/mapper/vgroup-lvswap
```

## 1.2 Install base and base-devel
```
pacman -S archlinux-keyring
pacman-key --refresh
pacstrap -i /mnt base base-devel
```

## 1.3 Generate fstab, with UUID
Automatically generate fstab
```
genfstab -U /mnt >> /mnt/etc/fstab
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
And prevent reloading the module
```
echo "blacklist pcspkr" >> /etc/modprobe.d/nobeep.conf
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
echo "FONT=lat9-16" >> /etc/vconsole.conf
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
rm /etc/localtime
ln -s /usr/share/zoneinfo/America/Anchorage /etc/localtime
```
Sync hardware clock with utc
```
hwclock --systohc --utc
```
#### 1.3.5 Define hostname
```
echo mull > /etc/hostname
```
And modify the host file accordingly
```
nano -w /etc/hosts
```
It should looks like
```
#<ip-address> <hostname.domain.org> <hostname>
127.0.0.1 localhost.localdomain localhost mull
::1   localhost.localdomain localhost mull
```
#### 1.3.6 Modify mkinitcpio.conf and rebuild boot image
Add modules and hooks
```
nano -w /etc/mkinitcpio.conf
```
Modify the lines
```
modules="... dm_raid ext4 raid1 ..."
...
hooks="... block keyboard ... mdadm_udev lvm2 encrypt resume  ... filesystems"
```
Rebuild the boot image
```
mkinitcpio -p linux
```
#### 1.3.7 Configure RAID array
Save the RAID configuration file for the boot image
```
mdadm --detail --scan >> /mnt/etc/mdadm.conf
```
#### 1.3.8 Root password
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
grub-install --target=i386-pc /dev/sda
grub-install --target=i386-pc /dev/sdb
```

#### 1.4.2 If needed, modify grub configuration
```
nano -w /etc/default/grub
```
Modifiy in the GRUB commandline for lvm and cryptdisk
```
GRUB_cmdline-linux="root=/dev/mapper/vgroup-lvroot"
GRUB_PRELOAD_modules="... lvm insmod mdraid1x"
```
And finally regenerate the grub.cfg
```
grub-mkconfig -o /boot/grub/grub.cfg
```
Reboot
```
umount /mnt{/home, /boot, /}
reboot
```

## 2. Packages and base configuration
## 2.0 set up networking and ssh
Enable wired interface at boot
```
sysetemctl enable dhcpcd@enp4s.service
sysetemctl enable start@enp4s0.service
```
Install **openssh**
```
pacman -S openssh
```
Configure sshd socket to listen to ports 1354
```
systemctl edit sshd.sockets
----------------
[Socket]
ListenStream=
ListenStream=1354
```
Enable sshd socket
```
systemctl enable sshd.socket
systemctl start sshd.socket
```


### 2.1 Create user
Create the user megavolts
```
useradd -m g users -G wheel, audio,locate,disk,lp,network -s /bin/bash megavolts
```
Create a password for megavolts
```
passwd megavolts
```
Install zsh shell and change /bin/bash to zsh for megavolts
```
sudo pacman -S grml-zsh-config
chsh -s $(which zsh)
```

### 2.1 Install yaourt aur package manager
Install dependencies
```
pacman -S curl yajl wget
```
Download and build package-query, as non-root user
```
wget https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=package-query
mv PKGBUILD?<bla> PKGBUILD
makepkg PKGBUILD
sudo pacman -U package-query-XXX
```
Install yaourt
```
wget https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=yaourt
mv PKGBUILD?<bla> PKGBUILD
makepkg PKGBUILD
sudo pacman -U yaourt-XXX
```

## 2.2 Set up pacman
```
pacman-key --refresh-keys
```
Set automatic mirror ranking
```
pacman -S reflector
```
Select the 200 most recently synchronized HTTP or HTTPS mirrors, sort them by download speed, and overwrite the file /etc/pacman.d/mirrorlist
```
reflector --latest 200 --protocol http --protocol https --sort rate --save /etc/pacman.d/mirrorlist
```
Download pacman hook to trigger reflector everytime pacman-mirrorlist get an update
```
wget https://raw.githubusercontent.com/megavolts/X220/master/script/mirrorupgrade.hook -P /etc/pacman.d/hooks/
```
