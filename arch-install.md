# Archlinux @ HPZ400

## 0. Computer Spec
### 0.1 Hard drives
* 2 x 1.0 To WD Green in raid for system (/dev/sda, /dev/sdc ==> /devmd126)
1 x 4 To SeaGate for storage
data storage backup @ mull in WRRB

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

Prepare system drive for GRUB/GPT install.
```
gdisk /dev/sda
```
Create following partition table
```
Number  Pat Type  FSType            Label       Size
1       Primary   BIOS/ef02         bios_grub   1.0 Mib
2       Primary   Linux/8300        boot        200.0 Mib
3      Primary    Linux RAID/fd00   LVM         931.3 GiB
```

If creating the raid array with only one disk:
```
mdadm --create --verbose --level=1 --metadata=1.2 --raid-devices=2 /dev/md0 missing/dev/sda2
mdadm --create --verbose --level=1 --metadata=1.2 --raid-devices=2 /dev/md1 missing/dev/sda3
```

##### to add the second disk later
Clone the partition scheme to /dev/sdb
```
sfdisk -d /dev/sda > sda.dump
sfdisk /dev/sdb < sda.dump
```

Encrypt the LVM RAID array /dev/md1
```
cryptsetup -c aes-xts-plain64 -s 512 -h sha512 -i 5000 --use-random --verify-passphrase luksFormat /dev/md1
```
Open the LVM RAID array
```
cryptsetup luksOpen /dev/md1 cryptdisk
```
Create the LV system
```
pvcreate /dev/mapper/cryptdisk
pvdisplay
vgcreate vgroup /dev/mapper/cryptdisk
vgdisplay
lvcreate --size 200G --name lvroot vgroup
lvcreate --contiguous y --size 16G --name lvswap vgroup
lvcreate --extents +100%FREE --name lvhome vgroup
lvdisplay
```

Create the filesystem
mkfs.ext4 /dev/mapper/vgroup-lvroot
mount /dev/mapper/vgroup-lvroot /mnt
mkfs.ext4 /dev/mapper/vgroup-lvhome
mkdir /mnt/home
mount /dev/mapper/vgroup-lvrhome /mnt/home
mkfs.ext4 /dev/md0
mkdir /mnt/boot
mount /dev/md0 /mnt/boot
mkswap /dev/mapper/vgroup-lvswap
swapon /dev/mapper/vgroup-lvswap
```

## 1.2 Install base and base-devel
```
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
BINARIES="/sbin/mdmon"
...
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
grub-install --target=i386-pc /dev/sdb
grub-install --target=i386-pc /dev/sdc
```

#### 1.4.2 If needed, modify grub configuration
```
nano -w /etc/default/grub
```
Modifiy in the GRUB commandline for lvm and cryptdisk
```
GRUB_cmdline-linux="cryptdevice=/dev/md1:cryptdisk root=/dev/mapper/vgroup-lvroot"
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
### 2.0 Create user
Create the user megavolts
```
useradd -m g users -G wheel, audio,locate,disk,lp,network -s /bin/bash
```
Create a password for megavolts
```
passwd megavolts
```
Install sudo
```
pacman -S sudo
```
Modify /etc/sudoers to give wheel group superpower
```
nano -w /etc/sudoers
```
Uncomment and add
```
%weel ALL=(ALL) ALL
...
Defaults insults
```
Logout as root and log as new user
Disable root user
```
passwd - l root
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
Download and build package-query
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
### 2.2 Configure and update pacman
Refresh signature keys
```
pacman-key --refresh-keys
```
##### 2.2.1 Reflector
```
yaourt -S reflector
```
Update the mirrorlist:
```
reflector --country 'United States' --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
```
Create a pacman hook to remove the .pacnew file created every time pacman-mirrorlist gets an upgrade.
```
nano -w /etc/pacman.d/hooks/mirrorupgrade.hook
```
and add
```
# /etc/pacman.d/hooks/mirrorupgrade.hook
[Trigger]
Operation = Upgrade
Type = Package
Target = pacman-mirrorlist

[Action]
Description = Updating pacman-mirrorlist with reflector and removing pacnew...
When = PostTransaction
Depends = reflector
Exec = /usr/bin/env sh -c "reflector --country 'United States' --latest 200 --age 24 --sort rate --save /etc/pacman.d/mirrorlist; if [[ -f /etc/pacman.d/mirrorlist.pacnew ]]; then rm /etc/pacman.d/mirrorlist.pacnew; fi"
```
Create a systemd service to trigger reflector everytime the computer boots
```
nano -w /etc/systemd/system/reflctor.service
```
and add
```
# etc/systemd/system/reflctor.service
[Unit]
Description=Pacman mirrorlist update
Requires=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/reflector --protocol https --latest 30 --number 20 --sort rate --save /etc/pacman.d/mirrorlist

[Install]
RequiredBy=multi-user.target

```
And activate the service
```
systemctl enable reflector.service
```

##### 2.2.1 Install powerpill
```
yaourt -S powerpill
```
Use powerpill instead of pacman

## 2.3 Install graphics
Install Xorg server
```
sudo powerpill -S xorg-server xorg-server-utils xorg-apps xf86-video-nouveau lib32-mesa lib32-libdrm libdrm mesa
```
Enabling nouveau in kernel module
```
nano /etc/mkinitcpio.conf
```
And add
```
MODULES="... nouveau"
```
Regenerate the initial image
```
mkinitcpio -p linux
```
Specify the nouveau driver for the kernel
```nano -w /etc/share/X11/xorg.conf.d/20-nouveau.conf```
With teh following content
```
Section "Device"
    Identifier "Nvidia card"
    Driver "nouveau"
EndSection
```

## 2.4 Install windows manager KDE
```
sudo powerpill -S plasma plasma-wayland-session sddm archlinux-theme-sddm
```
Copy default configuration for ssdm and modifiy it
```
sddm --example-config > /etc/sddm.conf
nano -w /etc/sddm.conf
```
With
```
...
Numlock=on
...
Current=archlinux-simplyblack
...
```
## 2.5 set up networking
Enable wired interface at boot
```
sysetemctl enable dhcpcd@enp1s.service
sysetemctl enable start@enp1s0.service
```
Enable wake-on-lan
```
yaourt -S ethtool
ethtool enp1s0 | grep Wake-on
```


### Other software
### 2.4.1 Drop-down termianl
```
yaourt -S tilda
yaourt -S ttf-dejavu ttf-freefont font-mathematica ttf-mathtype ttf-vista-fonts ttf-google-fonts-hg 
```


```
yaourt -S mlocate kwallet-pam ksshaskpass
```

yaourt -S sublime-text-dev

## 2.4.2 Internet
```
yaourt -S firefox thunderbird
```
