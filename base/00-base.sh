# /bin/bash
# TODO: INCLUDE computer mapping

# Dual boot with windows
# With 2 DISK
# Linux/Data Disk: /dev/nvme1n1
#  1            2048         8390655     4.0 giB   EF00  ARCHEFI
#  2         8390656       537921535   252.5 GiB   8300  CRYPTROOT
#  3       537921536      7814035455     3.4 TiB   8300  CRYPTDATA
# Windows Disk: /dev/nvme0n1


# TODO: Read from config file
WINDISK=/dev/nvme0n1
NUXDISK=/dev/nvme0n1
WINBOOTPART=1
NUXBOOTPART=1
NUXROOTPART=5
NUXDATAPART=5
NUXPHOTPART=6
NEWUSER=megavolts

NEWINSTALL=false
NEWROOT=true
WIPEDATA=false
NTFSDATA=false
TZDATA=America/Anchorage

echo 'Enter a default passphrase use to encrypt the disk and serve as password for root and megavolts:'
stty -echo
read PASSWORD
stty echo


echo -e ".. Mount subvolume for install"
# Mount root subvolume
# By default zstd compression level is 3, but need to override default zlib compression algorithm
# By default space_cache option is v2 (free space tree) since btrfs-progs 5.15
# By default discard=async is automatically enable for kernel>6.2
# By default btrfs enable or disable ssd according to `/sys/block/DEV/queue/rotational`
mount -o defaults,compress=zstd,noatime,nodev,subvol=@ /dev/mapper/root /mnt/

echo -e "... create root subvolume mountpoints"
mkdir -p /mnt/{efi,.efiwin,var/{abs,cache,log,lib/{docker,libvirt,containers},tmp},root,tmp,home,storage/{data,btrfs/root}}
mount -o defaults,compress=zstd,noatime,nodev,nodatacow,subvol=@var_log /dev/mapper/root /mnt/var/log
mount -o defaults,compress=zstd,noatime,nodev,nodatacow,subvol=@var_cache /dev/mapper/root /mnt/var/cache
mount -o defaults,compress=zstd,noatime,nodev,nodatacow,subvol=@root /dev/mapper/root /mnt/root
mount -o defaults,compress=zstd,noatime,nodev,nodatacow,subvol=@home /dev/mapper/root /mnt/home

echo -e "... mount root btrfs subvolume on /storage/btrfs/root"
mount -o defaults,compress=zstd,noatime,nodev /dev/mapper/root /mnt/storage/btrfs/root

# boot partition EFI and EFI_LINUX
echo -e ".. mount linux disk boot partition to /mnt/boot/efi"
mount /dev/disk/by-label/EFI /mnt/efi

if $DUALBOOT
  echo ".. EFI partition: preserve Windows Boot Loader"

  if [[ -f /mnt/efi/limine.conf ]]; then
    # remove previous kernel
    OLD_LIMINE=$(cat /mnt/efi/limine.conf | grep "_linux" | head -n 1 | cut -d '/' -f4 | cut -d '_' -f1)
    rm -R /mnt/limine.conf*
    rm -R /mnt/loader 
    rm -R /mnt/systemd
    rm -R /mnt/EFI/Linux 
    rm -R /mnt/EFI/limine
    rm -R /mnt/$OLD_LIMINE
  fi

if [[ $HOSTNAME == "vouivre" ]]; then
  echo -e ".. mount windows disk boot partition to /mnt/boot/efiwin"
  mount /dev/disk/by-label/EFIARCH /mnt/.efiarch
  # copy any windows boot information from EFI to EFIARCH
  # TODO: REMOVE AT DESTINATION TOO
  rsync /mnt/efi/ /mnt/.efiarch -hAr --info=progress2
fi

echo -e "Arch Linux Installation"
echo -e "... Enable parallel download"
sed -i 's|#Color|Color|' /etc/pacman.conf

echo -e ".. Install base packages"
pacman -Sy
pacstrap /mnt base linux-zen linux-zen-headers base-devel openssh doas ntp wget grml-zsh-config btrfs-progs networkmanager usbutils linux-firmware sof-firmware yajl mkinitcpio git go nano zsh terminus-font refind intel-ucode rsync iwd dhcpcd

# Enable unified 
echo -e ".. Install basic tools"
pacstrap /mnt plocate acl util-linux fwupd arp-scan htop lsof strace screen terminus-font plymouth less

echo -e "... [config] plocate: includes btrfs mountpoints when updateding the database"
sed -i 's|PRUNE_BIND_MOUNTS = "yes"|PRUNE_BIND_MOUNTS = "no"|' /mnt/etc/updatedb.conf
sed -i 's|\/media \/mnt|\/media \/mnt \/storage"|' /mnt/etc/updatedb.conf

echo -e ".. Create fstab"
genfstab -L -p /mnt >> /mnt/etc/fstab
sed 's/\/mnt\/swap/\/swap/g' /mnt/etc/fstab

echo -e " .. Allow wheel group for doas"
cat << EOF > /mnt/etc/doas.conf
permit persist setenv {PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin} :wheel
permit root as megavolts
EOF
chown -c root:root /mnt/etc/doas.conf
chmod -c 0400 /mnt/etc/doas.conf
arch-chroot /mnt bash -c "if doas -C /etc/doas.conf; then echo \"config ok\"; else echo \"config error\"; fi"

cat << EOF > /mnt/usr/local/bin/sudo
#!/bin/bash
exec doas "${@/--preserve-env*/}"
EOF

echo -e "Configure system"
# set timezone
echo -e ".. Set timezone to America/Anchorage"
ln -sf /usr/share/zoneinfo/${TZDATA} /mnt/etc/localtime
arch-chroot /mnt hwclock --systohc
echo ${TZDATA} > /mnt/etc/timezone
echo "#KEYMAP=us" >> /mnt/etc/vconsole.conf

# generate locales for en_US
echo -e ".. Set locale to en_US"
sed -e 's/#en_US/en_US/g' -i /mnt/etc/locale.gen
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
arch-chroot /mnt locale-gen

# set keyboard
echo -e ".. Set keyboard"
echo "FONT=ter-132n" >> /mnt/etc/vconsole.conf

# set hostname
echo -e ".. Set hostname & network manager"
echo $HOSTNAME > /mnt/etc/hostname
echo "127.0.1.1 localhost $HOSTNAME.localdomain    $HOSTNAME" >> /mnt/etc/hosts
echo "::1 localhost $HOSTNAME" >> /mnt/etc/hosts

if [ -d /mnt/home/$NEWUSER ]; then
  mv /mnt/home/$NEWUSER /mnt/home/$NEWUSER.$(date +%Y%m%d)
fi

# cryptfile to decrypt data
if [[ $HOSTNAME == "vouivre" ]]; then
  echo -e ".. Add cryptkey to data partition"
  dd if=/dev/urandom of=/mnt/etc/cryptfs.key bs=1024 count=1
  chmod 600 /mnt/etc/cryptfs.key 
  CRYPTUUID=$(cryptsetup luksDump /dev/disk/by-partlabel/CRYPTDATA | grep UUID | cut -f2- -d: | sed -e 's/^[ \t]*//')
  echo -en $PASSWORD | cryptsetup luksAddKey /dev/disk/by-uuid/$CRYPTUUID /mnt/etc/cryptfs.key 
fi

### USERS ###
echo -e "Create user"
echo 'Enter a default passphrase use to encrypt the disk and serve as password for root and megavolts:'
stty -echo
read PASSWORD
stty echo
# ROOT options
echo -e "Set root password"
arch-chroot /mnt passwd root << EOF
$PASSWORD
$PASSWORD
EOF
arch-chroot /mnt chsh -s $(which zsh)

# USER options
echo -e "Set up user $NEWUSER"
echo -e ".. create $NEWUSER with default password"
arch-chroot /mnt useradd -m -g users -G wheel,audio,disk,lp,network -s /bin/zsh $NEWUSER
arch-chroot /mnt passwd $NEWUSER << EOF
$PASSWORD
$PASSWORD
EOF

# Unified kernel with systemd-boot
ROFFSET=$(btrfs inspect-internal map-swapfile -r /mnt/storage/btrfs/root/@swap/swapfile)
ROOTUUID=$(cryptsetup luksDump /dev/disk/by-partlabel/CRYPTROOT | grep UUID | cut -f2- -d: | sed -e 's/^[ \t]*//')

# Configure  cmdline
echo "loglevel=3 rd.luks.name=$ROOTUUID=root root=/dev/mapper/root rootfstype=btrfs rootflags=subvol=/@ rw resume=/dev/mapper/root resume_offset=$ROFFSET quiet splash" >> /mnt/etc/kernel/cmdline
mkdir /mnt/etc/cmdline.d
echo "rd.luks.name=$ROOTUUID=root root=/dev/mapper/root rootfstype=btrfs rootflags=subvol=/@ rw resume=/dev/mapper/root resume_offset=$ROFFSET quiet splash" >> /mnt/etc/cmdline.d/root.conf

# Adjust mkinitcpio.conf
# add sd-encrypt and plymouth to hooks. 
sed -i 's/sd-vconsole /sd-vconsole plymouth sd-encrypt /g' /mnt/etc/mkinitcpio.conf

# Configure Unified Kernel Image UKI
sed -i 's/ALL_config/#ALL_config /g' /mnt/etc/mkinitcpio.d/linux-zen.preset
sed -i 's/#ALL_kver/ALL_kver/g' /mnt/etc/mkinitcpio.d/linux-zen.preset

sed -i "s/PRESETS=('default')/#PRESETS=('default')/g" /mnt/etc/mkinitcpio.d/linux-zen.preset
sed -i "s/#PRESETS=('default' 'fallback')/PRESETS=('default' 'fallback')/g" /mnt/etc/mkinitcpio.d/linux-zen.preset

sed -i 's/default_image/#default_image/g' /mnt/etc/mkinitcpio.d/linux-zen.preset
sed -i 's/#default_uki/default_uki/g' /mnt/etc/mkinitcpio.d/linux-zen.preset
sed -i 's/#default_options/default_options/g' /mnt/etc/mkinitcpio.d/linux-zen.preset

sed -i 's/fallback_image/#fallback_image/g' /mnt/etc/mkinitcpio.d/linux-zen.preset
sed -i 's/#fallback_uki/fallback_uki/g' /mnt/etc/mkinitcpio.d/linux-zen.preset
sed -i 's/#fallback_options/fallback_options/g' /mnt/etc/mkinitcpio.d/linux-zen.preset

mkdir -p /mnt/efi/EFI/Linux

arch-chroot /mnt mkinitcpio -P

# Enable base service
echo -e ".. Start services"
systemctl --root /mnt enable NetworkManager
systemctl --root /mnt enable sshd
systemctl --root /mnt enable btrfs-scrub@home.timer 
systemctl --root /mnt enable btrfs-scrub@-.timer 
systemctl --root /mnt enable fstrim.timer

pacstrap /mnt limine
mkdir /mnt/efi/EFI/Limine
cp /mnt/usr/share/limine/BOOTX64.EFI /mnt/efi/EFI/Limine/
## Create Limine boot entry via efibootmgr
arch-chroot /mnt bootctl install --esp-path=/efi
arch-chroot /mnt efibootmgr --create --disk $NUXDISK --part $NUXBOOTPART --label "Limine Boot Loader" \
      --loader '\EFI\Limine\BOOTX64.EFI' --unicode
cat << EOF > /mnt/efi/limine.conf
timeout: 5
/+Arch Linux
    protocol: efi
    path: boot():/EFI/Linux/arch-linux-zen.efi
    cmdline: loglevel=3 rd.luks.name=$ROOTUUID=root root=/dev/mapper/root rootfstype=btrfs rootflags=subvol=/@ rw resume=/dev/mapper/root resume_offset=$RESUME_OFFSET quiet splash
/Memtest86+
    protocol: efi
    path: boot():/memtest86+/memtest.efi
/Windows
    protocol: efi
    path: boot():/EFI/Microsoft/Boot/bootmgfw.efi
EOF

echo -e "Tuning pacman"
echo -e ".. Enable multilib" 
sed -i 's|#[multilib]|[multilib]|' /mnt/etc/pacman.conf
sed -i "/\[multilib\]/,/Include/"'s/^#//' /mnt/etc/pacman.conf
sed -i 's|#ParallelDownloads|ParallelDownloads|' /mnt/etc/pacman.conf
sed -i 's|#Color|Color|' /mnt/etc/pacman.conf

echo -e ".. Update pacman and system "
arch-chroot /mnt pacman -Syy
arch-chroot /mnt pacman -S --noconfirm archlinux-keyring rebuild-detector
arch-chroot /mnt pacman-key --init
arch-chroot /mnt pacman-key --populate archlinux
arch-chroot /mnt pacman -Syu --noconfirm
# Disable build of debug packages
echo -e "... disable build of debug packge when using makepkg"
sed -i "s| debug lto| \!debug lto|g" /etc/makepkg.conf

echo -e ".. Optimize mirrorlist"
arch-chroot /mnt pacman -S --noconfirm reflector
sed -i "s|# --country France,Germany|--country USA,Switzerland|g" /mnt/etc/xdg/reflector/reflector.conf
arch-chroot /mnt systemctl enable reflector.timer

echo -e "Install aur package manager"
arch-chroot /mnt wget https://aur.archlinux.org/cgit/aur.git/snapshot/package-query.tar.gz
arch-chroot /mnt tar -xvzf package-query.tar.gz -C /home/$NEWUSER
arch-chroot /mnt chown ${NEWUSER}:users /home/$NEWUSER/package-query -R
arch-chroot /mnt doas -u ${NEWUSER} bash -c "makepkg -s --noconfirm -D /home/$NEWUSER/package-query"
arch-chroot /mnt bash -c "pacman -U --noconfirm /home/${NEWUSER}/package-query/package-query-*.zst"
arch-chroot /mnt doas -u ${NEWUSER} bash -c "yay --sudo doas --sudoflags -- --save"
arch-chroot /mnt wget https://aur.archlinux.org/cgit/aur.git/snapshot/yay.tar.gz
arch-chroot /mnt tar -xvzf yay.tar.gz -C /home/$NEWUSER
arch-chroot /mnt chown ${NEWUSER}:users /home/$NEWUSER/yay -R
arch-chroot /mnt doas -u ${NEWUSER} bash -c "makepkg -s --noconfirm -D /home/$NEWUSER/yay"
arch-chroot /mnt bash -c "pacman -U --noconfirm /home/${NEWUSER}/yay/yay-*.zst"
arch-chroot /mnt rm -R /home/${NEWUSER}/{yay,package-query}

## FOR P1 only
if [[ $HOSTNAME == "vouivre" ]]; then
  echo -e ".. Set up crypttab to unlock data"
  DATAUUID=$(cryptsetup luksDump /dev/disk/by-partlabel/CRYPTDATA | grep UUID | cut -f2- -d: | sed -e 's/^[ \t]*//')
  echo "data   UUID=$DATAUUID  /etc/cryptfs.key" >> /etc/crypttab
fi

## Intel Graphics Software
echo -e "Graphic interface"
echo -e ".. Install drivers specific to Intel Corporation Alder Lake-P Integrated Graphics Controller"
# X1YogaG6: TigerLake is after haswell
arch-chroot /mnt pacman -S --noconfirm mesa vulkan-intel vulkan-mesa-layers intel-media-driver
# Enable GuC/HuC firmware loading
echo "options i915 enable_guc=3" >> /mnt/etc/modprobe.d/i915.conf

yays(){doas -u $NEWUSER bash -c "yay -S --removemake --cleanafter --noconfirm $1"}
#echo "permit nopass megavolts as root" >>  /mnt/etc/doas.conf
echo "permit nopass root as megavolts" >> /mnt/etc/doas.conf

# Packages list redone as 2025-04-02
# Windows Manager

arch-chroot /mnt pacman -S --noconfirm plasma-desktop pipewire-jack qt6-multimedia-ffmpeg plasma-thunderbolt pinentry kwalletmanager kwallet-pam kinfocenter kruler plasma-login-manager plymouth-kcm
systemctl --root /mnt enable plasmalogin.service

# Power
echo -e "... power management"
arch-chroot /mnt pacman -S --noconfirm powerdevil power-profiles-daemon
systemctl --root /mnt enable power-profiles-daemon

echo -e "... audio server"
arch-chroot /mnt pacman -S --noconfirm  pipewire wireplumber pavucontrol plasma-pa 

echo -e "... graphic tools"
arch-chroot /mnt pacman -S --noconfirm  deskflow kscreen wl-clipboard colord-kde imagemagick guetzli geeqie inkscape gimp darktable inkscape libraw hugin

echo -e ".. install software"
echo -e "... terminal"
arch-chroot /mnt pacman -S --noconfirm  yakuake kdialog kfind kdeconnect dg-desktop-portal-kde solaar

echo -e ".. coding tools"
arch-chroot /mnt pacman -S --noconfirm  code
yays sublime-text-4 oh-my-zsh-git pycharm

echo -e "... network tools"
arch-chroot /mnt pacman -S --noconfirm  plasma-nm networkmanager-openvpn dnsmasq

echo -e "... bluetooth"
arch-chroot /mnt pacman -S --noconfirm  bluez bluez-utils bluedevil
systemctl --root /mnt enable bluetooth.service

echo -e ".... partition tools"
arch-chroot /mnt pacman -S --noconfirm  gparted ntfs-3g exfatprogs mtools sshfs dosfstools
yays bindfs

echo -e ".... file manager"
arch-chroot /mnt pacman -S --noconfirm  dolphin dolphin-plugins ark p7zip zip ffmpegthumbs kdegraphics-thumbnailers kdenetwork-filesharing kdf kio-admin kompare purpose
yays raw-thumbnailer

echo -e "... android tools"
arch-chroot /mnt pacman -S --noconfirm  android-tools android-udev 

echo -e ".;. internet software"
arch-chroot /mnt pacman -S --noconfirm  firefox thunderbird filezilla zoom slack-wayland transmission-qt
yays  zoom

echo -e ".. sync software"
yays c++utilities qtutilities-qt6 qtforkawesome-qt6 syncthingtray-qt6 nextcloud-client 

echo -e "... viewer"
arch-chroot /mnt pacman -S --noconfirm  okular spectacle tesseract-data-eng tesseract-data-fra

echo -e "... video"
arch-chroot /mnt pacman -S --noconfirm  vlc ffmpeg vlc-plugins-all

pacman -S libreoffice-fresh libreoffice-extension-texmaths
pacman -S aspell-fr aspell-en aspell-de hunspell-en_US hunspell-fr-comprehensive hunspell-de hyphen-en hyphen-en hyphen-de libmythes mythes-en mythes-fr
yays zotero-bin libreoffice-extension-grammalecte-fr

echo -e " ..  Install pacman and downgrade tools"
yays paccache-hook downgrade

echo -e ".. virtualization tools"
pacman -S virtualbox virtualbox-guest-iso virtualbox-host-dkms
yays virtualbox-ext-oracle

pacman -S ttf-droid
yays neofetch
echo neofetch >> /mnt/home/$NEWUSER/.zshrc

echo -e ".. Installing tailscale, follow the link to login"
pacman -S tailscale
yays traysacle

echo -e "Install snapper, a snapshots manager "
pacman -S snapper
yays snapper-gui-git snap-pac

pacman -S qgis

echo -e "... file sharing"
pacman -S samba kdenetwork-filesharing

# Enable snapshots with snapper
echo -e ".. Configure snapper"
echo -e "... Create root config"

# Delete any /.snapshots adn /home/.snapshots directory or subvolume
if [ -d "/.snapshots" ]; then
  rmdir /.snapshots
fi


# Create root and home snapper config
snapper -c root create-config /
btrfs subvolume delete /.snapshots
mkdir /.snapshots
if ! [ -d /storage/btrfs/root/@snapshots/@root_snaps ] ; then
  if ! [ -d /storage/btrfs/root/@snapshots ] ; then
    btrfs subvolume create /storage/btrfs/root/@snapshots
  fi
  btrfs subvolume create /storage/btrfs/root/@snapshots/@root_snaps
fi

snapper -c home create-config /home/
btrfs subvolume delete /home/.snapshots
mkdir /home/.snapshots
if ! [ -d /storage/btrfs/root/@snapshots/@home_snaps ] ; then
  if ! [ -d /storage/btrfs/root/@snapshots ] ; then
    btrfs subvolume create /storage/btrfs/root/@snapshots
  fi
  btrfs subvolume create /storage/btrfs/root/@snapshots/@home_snaps
fi

echo -e ".. add entry to fstab and mount"
echo "# Snapper subvolume"  >> /etc/fstab
echo "/dev/mapper/root /.snapshots btrfs rw,noatime,compress=zstd,subvol=@snapshots/@root_snaps   0 0" >> /etc/fstab
if [[ $HOSTNAME == "vouivre" ]]; then
  echo "/dev/mapper/data /home/.snapshots btrfs rw,noatime,compress=zstd,subvol=@snapshots/@home_snaps   0 0" >> /etc/fstab
elif [[ $HOSTNAME == "dahu" ]]; then
  echo "/dev/mapper/root /home/.snapshots btrfs rw,noatime,compress=zstd,subvol=@snapshots/@home_snaps   0 0" >> /etc/fstab
fi
systemctl daemon-reload && mount -a

echo -e ".. Edit home and root configuration"
echo -e "... Allow user $NEWUSER to modify snapper config"
setfacl -Rm "u:${NEWUSER}:rwx" /etc/snapper/configs
setfacl -Rdm "u:${NEWUSER}:rwx" /etc/snapper/configs

echo -e "... Allow user $NEWUSER and usergroup wheel to modify snapper"
sed -i "s|ALLOW_USERS=\"|ALLOW_USERS=\"${NEWUSER}|g" /etc/snapper/configs/root
sed -i "s|ALLOW_GROUPS=\"|ALLOW_GROUPS=\"wheel|g" /etc/snapper/configs/root
sed -i "s|ALLOW_USERS=\"|ALLOW_USERS=\"${NEWUSER}|g" /etc/snapper/configs/home
sed -i "s|ALLOW_GROUPS=\"|ALLOW_GROUPS=\"wheel|g" /etc/snapper/configs/home
echo -e "... Enable ACL"
sed "s|SYNC_ACL=\"no|SYNC_ACL=\"yes|g" -i /etc/snapper/configs/root
sed "s|SYNC_ACL=\"no|SYNC_ACL=\"yes|g" -i /etc/snapper/configs/home
echo -e "... Change Timeline limit for snapshot retention"
# update snap config for root directory
sed  -i "s|TIMELINE_MIN_AGE=\"3600\"|TIMELINE_MIN_AGE=\"0\"|g"            /etc/snapper/configs/root  # Allow all snapshots to be removed, independantly of age
sed  -i "s|TIMELINE_LIMIT_HOURLY=\"10\"|TIMELINE_LIMIT_HOURLY=\"12\"|g"   /etc/snapper/configs/root  # keep hourly backup for 12 hours
sed  -i "s|TIMELINE_LIMIT_DAILY=\"10\"|TIMELINE_LIMIT_DAILY=\"7\"|g"     /etc/snapper/configs/root   # keep daily backup for 7 days
sed  -i "s|TIMELINE_LIMIT_WEEKLY=\"0\"|TIMELINE_LIMIT_WEEKLY=\"4\"|g"     /etc/snapper/configs/root  # keep weekly backup for 4 weeks
sed  -i "s|TIMELINE_LIMIT_MONTHLY=\"12\"|TIMELINE_LIMIT_MONTHLY=\"12\"|g" /etc/snapper/configs/root  # keep monthly backup for 12 months
sed  -i "s|TIMELINE_LIMIT_YEARLY=\"5\"|TIMELINE_LIMIT_YEARLY=\"5\"|g"     /etc/snapper/configs/root  # keep yearly backup for 5 years
# # update snap config for home directory
sed  -i "s|TIMELINE_MIN_AGE=\"3600\"|TIMELINE_MIN_AGE=\"7200\"|g"         /etc/snapper/configs/home  # Keep all snapshots within the last 2 hours
sed  -i "s|TIMELINE_LIMIT_HOURLY=\"10\"|TIMELINE_LIMIT_HOURLY=\"96\"|g"   /etc/snapper/configs/home  # keep hourly backup for 96 hours (4 days)
sed  -i "s|TIMELINE_LIMIT_DAILY=\"10\"|TIMELINE_LIMIT_DAILY=\"14\"|g"     /etc/snapper/configs/home  # keep daily backup for 14 days (2 weeks)
sed  -i "s|TIMELINE_LIMIT_WEEKLY=\"0\"|TIMELINE_LIMIT_WEEKLY=\"4\"|g"     /etc/snapper/configs/home  # keep weekly backup for 4 weeks (1 month)
sed  -i "s|TIMELINE_LIMIT_MONTHLY=\"10\"|TIMELINE_LIMIT_MONTHLY=\"12\"|g" /etc/snapper/configs/home  # keep monthly backup for 12 months (1 year)
sed  -i "s|TIMELINE_LIMIT_YEARLY=\"10\"|TIMELINE_LIMIT_YEARLY=\"10\"|g"     /etc/snapper/configs/home  # keep yearly backup for 5 years (1 decade)

echo -e ".. Remove snapshots from mlocate database"
sed -i 's/PRUNENAMES = "/PRUNENAMES = ".snapshots /g' /etc/updatedb.conf

echo -e " ... Execute snapshots cleanup every hour"
SYSTEMD_EDITOR=tee systemctl edit snapper-cleanup.timer <<EOF
[Timer]
OnBootSec=10min
OnUnitActiveSec=1h
EOF

echo -e "... Take a snapshots every 5 minutes"
SYSTEMD_EDITOR=tee systemctl edit snapper-timeline.timer <<EOF
[Timer]
OnCalendar=*:0/5
EOF

# enable snapshot at boot
echo -e "... Take a snapshots at boot after mounting /.snapshots"
systemctl enable snapper-boot.timer
SYSTEMD_EDITOR=tee systemctl edit snapper-boot.service <<EOF
[Unit]
After=\\\\x2eboot.mount
EOF

echo -e ".. Enable and start snapshots timer"
systemctl start --now snapper-timeline.timer snapper-cleanup.timer snapper-boot.timer # start and enable snapper


# Generic Tune UP
# echo "Allow other_user for fuse"
# sed  -i "s|#user_allow_other|user_allow_other|g"        /etc/fuse.conf



# ON REBOOT
systemctl enable --now tailscaled
tailscale up --ssh --accept-routes




# TODO: slack-wayland

# # # Set up automatic copy of boot partition on kernel update to enable backup to /.boot
# 2026-06-17: likely not needed
# # cat << EOF >  /usr/share/libalpm/hooks/91-boot_backup_after.hook
# # [Trigger]
# # Type = Path
# # Operation = Install
# # Operation = Upgrade
# # Target = usr/lib/modules/*/vmlinuz
# # Target = usr/lib/initcpio/*
# # Target = usr/src/*/dkms.conf

# # [Action]
# # Depends = rsync
# # Description = Backing up /boot...
# # When = PostTransaction
# # Exec = /bin/sh -c "/usr/bin/rsync -avh --delete /efi /.efibkp"
# # EOF
# # mkdir /.efibkp
# if [[ $HOSTNAME == "vouivre" ]]; then
#   sed -i 's|/.efibkp"|/.efibkp \&\& /usr/bin/rsync -avh --delete /efi /.efiarch"|g' /usr/share/libalpm/hooks/91-boot_backup_after.hook
# fi

swapoff /mnt/storage/btrfs/root/@swap/swapfile
umount /mnt/{boot,.bootwin,storage,storage/data,storage/btrfs/root,storage/btrfs/data,var/log,var/tmp,/tmp,/var/cache/pacman/pkg,var/abs,/home}
reboot



# TODO MEGE 01-chrrot here
#systemctl reboot
# After reboot chroot
# ## Tuning
# echo -e ""
# echo -e ".. generic tuning"
# wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/config/X1yoga6-01-generic_config-V2.sh
# chmod +x generic_config-V2.sh
# cp generic_config-V2.sh /mnt/ 
# arch-chroot /mnt ./generic_config-V2.sh $PWD $USER adak
# rm /mnt/generic_config-V2.sh

# ## Specific tuning
# echo -e ""
# echo -e ".. Specific X220 tuning"
# wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/X220/source/specific_config.sh
# chmod +x specific_config.sh
# cp specific_config.sh /mnt/
# arch-chroot /mnt ./specific_config.sh $TANK_DEV_PART $FORMAT_TANK
# rm /mnt/specific_config.sh
    
# ## Install software packages
# echo -e ""
# echo -e ".. Install software packages"
# wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/source/software_install.sh
# chmod +x software_install.sh
# cp specific_config.sh /mnt/
# arch-chroot /mnt ./specific_config.sh $root_dev $home_dev

# # rm /mnt/{software_install.sh, specific_config.sh, generic_config.sh}
# # umount /mnt{/boot,/home,/}
