
NEWUSER=megavolts

# remove 
if [ -d /home/$NEWUSER/.cache/yay ]
then
	sudo rm -R /home/$NEWUSER/.cache/yay/*
fi
mkdir -p /home/$NEWUSER/Pictures/{photography,wallpapers,memes,drawings}
mkdir -p /home/$NEWUSER/Videos/{tvseries,movies,videos}

btrfs create subvolume /mnt/btrfs-arch/@$NEWUSER
btrfs create subvolume /mnt/btrfs-arch/@$NEWUSER/@downloads
btrfs create subvolume /mnt/btrfs-arch/@$NEWUSER/@yay

echo "LABEL=arch      /home/megavolts/.cache/yay              btrfs   rw,noatime,compress=lzo,ssd,discard,space_cache=v2,commit=120,nodatacow,subvol=@yay       0 0" >> /etc/fstab
echo "LABEL=arch      /home/megavolts/Downloads               btrfs   rw,noatime,compress=lzo,ssd,discard,space_cache=v2,commit=120,nodatacow,subvol=@megavolts/@downloads       0 0" >> /etc/fstab
echo "/dev/nvme0n1p6  /home/megavolts/Pictures/photography    ntfs-3g rw,default,automount,user,gid=984,uid=1000,dmask=0022,fmask=133       0 0" >> /etc/fstab
echo "\n#Media overlay" >> /etc/fstab
echo "/mnt/data/media/musics    /home/megavolts/Music       none     default 0 0" >> /etc/fstab
echo "/mnt/data/media/wallpaper       /home/megavolts/Pictures/wallpapers       none     default 0 0" >> /etc/fstab
echo "/mnt/data/media/meme            /home/megavolts/Pictures/memes       none     default 0 0" >> /etc/fstab
echo "/mnt/data/media/graphisme       /home/megavolts/Pictures/drawings       none     default 0 0" >> /etc/fstab
echo "/mnt/data/media/tvseries  /home/megavolts/Videos/tvseries       none     default 0 0" >> /etc/fstab
echo "/mnt/data/media/movies    /home/megavolts/Videos/movies       none     default 0 0" >> /etc/fstab
echo "/mnt/data/media/videos    /home/megavolts/Videos/videos       none     default 0 0" >> /etc/fstab

sudo systemctl daemon-reload && mount -a

# set up protonmail

# set profile-sync-daemon
yay -S --noconfirm profile-sync-daemon
echo -e "... configure profile-sync-daemon to improve speed, reduced wear to physical drives"
sudo echo "megavolts ALL=(ALL) NOPASSWD: /usr/bin/psd-overlay-helper" >> /etc/sudoers
mkdir /home/megavolts/.config/psd/
wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/config/psd.conf -O /home/megavolts/.config/psd/psd.conf
systemctl enable --now --user psd

# Yakuake transparency:
# >> edit  profile appearrance
