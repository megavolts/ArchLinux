# X220 - Arch/Win
## 0 System
* Thinkpad Lenovo X220
* UEFI, dualboot Windows X and LUKS archlinux
* 1x 1To data storage
* 1x 512Go SSD OS

### Partition table
#### OS SSD
Partition SSD with GPT table
```
   Name        Flags      Part Type  FS Type       [Label]                 Size
----------------------------------------------------------------------------------------------
   sdb1        Boot        Primary   efi (ef00)    EFI system partition     520.0M # /boot/efi
   sdb2                    Primary   X             MSR (reserved)            16.0M # 
   sdb3                    Primary   ntfs          WinX                     125.0G #
   sdb4                    Primary   ext4 (8300)   cryptroot                125.0G # /
   sdb5                    Primary   ext4 (8300)   crypthome                215.2G # /home
```

#### data HD
Partition HD with GPT table
```
   Name        Flags      Part Type  FS Type       [Label]                 Size
----------------------------------------------------------------------------------------------
   sda1                   Primary    ext4 (ef00)   cryptdata               931.5G # /mnt/data
```

### Windows Installation
As usual


## 1. Arch instllation 
To simplify the installation of linux, one the isntaller launch,

```
wget https://github.com/megavolts/ArchLinux/edit/master/X220/archlinux_reinstall_script.sh
chmod +x archlinux_reinstall_script.sh
./archlinux_reinstall_script.sh
```
Then boot

## 1.1 Encrypt partitions
Encrypt root partition with a password
```
cryptsetup -c aes-xts-plain64 -s 512 -h sha512 -i 5000 --use-random --verify-passphrase luksFormat /dev/sdb4
cryptsetup luksOpen /dev/sdb4 cryptroot
mkfs.ext4 /dev/mapper/cryptroot
mount /dev/mapper/cryptroot /mnt
```

Encrypt data partition with a password and add a decrypt file
```
cryptsetup -c aes-xts-plain64 -s 512 -h sha512 -i 5000 --use-random --verify-passphrase luksFormat /dev/sda3
dd if=/dev/urandom of=/mnt/home.keyfile bs=512 count=4
cryptsetup luksAddKey /dev/sdb5 /mnt/home.keyfile
cryptestup luksOpen /dev/sdb5 -d /mnt/home.keyfile crypthome
mkfs.ext4 /dev/mapper/crypthome
mkdir /mnt/home
mount /dev/mapper/crypthome /mnt/home
```

Create swap file on root
```
fallocate -l 16G /mnt/swapfile
chmod 0600 /mnt/swapfile
mkswap /mnt/swapfile
swapon /mnt/swapfile
```

## 1.2 Install base and basedevel
```
pacman -S archlinux-keyring
pacman-key --refresh
pacstrap /mnt base base-devel
```

Copy partition table
```
genfstab -U -p /mnt >> /mnt/etc/fstab
```

## 1.3 Config
```
arch-chroot /mnt
```

update system
```
nano -w /etc/pacman.conf
----------------------------------------------------------------------------------------------
[multilib]
Include = /etc/pacman.d/mirrorlist
```
And update pacman
```
pacman -Syu
pacman -S archlinux-keyring
pacman-key --init
pacman-key --populate archlinux
pacman -Syu
```
Set default console font and keymap
```
echo "FONT=lat9w-16" >> /etc/vconsole.conf
```

Define local to American English
```
nano -w /etc/locale.gen
----------------------------------------------------------------------------------------------
en_US.UTF-8 UTF-8
```
Update locales
```
locale-gen
export LANG=en_US.UTF-8
```

Define timezone
```
rm /etc/localtime
ln -sf /usr/share/zoneinfo/America/Anchorage /etc/localtime
hwclock --systohc --utc
``` 

Set hostname
```
echo islay > /etc/hostname
#nano -w /etc/hosts
#----------------------------------------------------------------------------------------------
##<ip-address> <hostname.domain.org> <hostname>
#127.0.0.1 localhost.localdomain localhost adak
#::1   localhost.localdomain localhost adak
```

Modify modules and hooks in mkinitcpio.conf
```
nano -w /etc/mkinitcpio.conf
----------------------------------------------------------------------------------------------
modules="... nls_cp437 ext4 vfat  ..."
hooks="... block keyboard ... encrypt resume ... filesystems"
```
Change kernel to linux-zen
```
pacman -S linux-zen
pacamn -Rns linux
```

Rebuild the initramfs
```
mkinitcpio -p linux
```

Define root password
```
passwd
```
Enable network
```
systemctl enable dhcpcd@enp1s0
```


## 1.4 Install bootloader
```
pacman -S refind-efi
refind-install
```        

Create a cryptab entry 
```
nano -w /etc/crypttab
----------------------------------------------------------------------------------------------
home  /dev/sdb5   /etc/home.keyfile
```
Exit and reboot
```
exit
umount /mnt/{boot/efi, boot, home}
reboot
```

# Basic tuning
Create user
```
useradd -m g users -G wheel,audio,disk,lp,network -s /bin/bash megavolts
passwd megavolts
```
Give user, sudo right
```
nano -w /etc/sudoers
----------------------------------------------------------------------------------------------
%wheel ALL=(ALL) ALL
```
Set up secure shell
```
pacman -S openssh
systemctel edit sshd.socket
----------------------------------------------------------------------------------------------
[Socket]
ListenStream
ListenStream=1354
```
Launch sshd socket
```
systemctl start sshd.socket
systemctl enable sshd.socket
```

## 3.0 Install yaourt
Install dependencies
```
pacman -S yajl wget
```
Download and build package-query and yaourt:
```
wget https://aur.archlinux.org/cgit/aur.git/snapshot/package-query.tar.gz
tar -xvzf package-query.tar.gz
cd package-query
makepkg -si
cd ..
wget https://aur.archlinux.org/cgit/aur.git/snapshot/yaourt.tar.gz
tar -xvzf yaourt.tar.gz
cd yaourt
makepkg -si

cd ../
rm -rf package-query/ package-query.tar.gz yaourt/ yaourt.tar.gz
```
## 3.1 Change shell
```
yaourt -S grml-zsh-config
chsh -s $(which zsh)
```

## 3.2 Set up pacman
Set automatic mirror ranking
```
yaourt  -S reflector
```
Select the 200 most recently synchronized HTTP or HTTPS mirrors, sort them by download speed, and overwrite the file /etc/pacman.d/mirrorlist
```
sudo reflector --latest 200 --protocol http --protocol https --sort rate --save /etc/pacman.d/mirrorlist
```
Download pacman hook to trigger reflector everytime pacman-mirrorlist get an update
```
wget https://raw.githubusercontent.com/megavolts/X220/master/script/mirrorupgrade.hook -P /etc/pacman.d/hooks/
```

## 3.2 Set graphical server (intel graphic card)
```
pacman -S xorg-server xorg-apps xf86-video-intel mesa-libgl lib32-mesa-libgl libva-intel-driver libva xorg-xinit xorg-xrandr
```
Add i915 to the modules ini mkinitcpio.conf
```
nano /etc/mkinitcpio.conf
--------------------------------------------------------------------------------------------------------------------------------
modules = " ... i915"
```
Rebuild the initramfs
```
mkinitcpio -p linux-zen
```
Configure i915 options
```
echo "options i915 enable_rc6=1 enable_fbc=1 lvds_downclock=1" >> /etc/modprobe.d/i915.conf
```
Install input packages
```
pacman -S xf86-input-synaptics xf86-input-keyboard xf86-input-wacom xf86-input-mouse
```

## 3.3 Install plasma windows manager
```
yaourt -S plasma-desktop sddm kdenetwork
```
With `phonon-qt5-vlc` and `libx264-10bit`

Copy default configuration for ssdm and modifiy it
```
sddm --example-config > /etc/sddm.conf
```
Configure sddm
```
nano -w /etc/sddm.conf
-------------------------------------
Numlock=on
[Theme]
# Current theme name
#Current=archlinux-simplyblack
Current=breeze
CursorTheme=breeze_cursors
```
Try sddm:
```
systemctl start sddm
```
If it works, reboot and enable sddm
```
reboot
systemctl enable sddm
```

## 3.5 Networking
Enable plasma 5 networking applet
```
pacman -S networkmanager
systemctl enable NetworkManager.service
systemctl start NetworkManager.service
```
We can also automate the hostname setup using the following systemd command:
```
hostnamectl set-hostname adak
```

## 3.4 Install audio server
```
yaourt -S alsa-utils pulseaudio pulseaudio-alsa
yaourt -S pulseaudio-jack pulseaudio-equalizer kmix  
yaourt -S libcanberra-pulse libcanberra-gstreamer
```

## 3.5 X220 tuning
### 3.4.1 keyboard and synaptics
  wget pastebin.com/download.php?i=mD3zfa08
  mv download.php?i=mD3zfa08 /etc/X11/xorg.conf.d/50-synaptics.conf
  wget pastebin.com/download.php?i=xNAHjAC5
  mv download.php?i=mD3zfa08 /etc/X11/xorg.conf.d/20-keyboard.conf
  
## KDE
# Applets
* powerdevil for power manager
* plasma-nm for network manager
* kscreen for display manager
