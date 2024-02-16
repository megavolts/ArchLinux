
# echo -e ".. virtualization tools"
yay -S --noconfirm virtualbox virtualbox-guest-iso virtualbox-host-dkms virtualbox-ext-oracle
# # For cursor in wayland session
# echo "KWIN_FORCE_SW_CURSOR=1" >> /etc/environement


# BTRFS data subvolume
if [ !  -e /mnt/btrfs/data/@media ]
then
  btrfs subvolume create /mnt/btrfs/data/@media 
fi
if [ !  -e /mnt/btrfs/data/@photography ]
then
  btrfs subvolume create /mnt/btrfs/data/@photography
fi
if [ !  -e /mnt/btrfs/data/@UAF-data ]
then
  btrfs subvolume create /mnt/btrfs/data/@UAF-data
fi

mkdir -p /mnt/data/{media,UAF-data}
mkdir -p /mnt/data/media/{photography,wallpaper,meme,graphisme,tvseries,movies,videos,musics}
echo "/dev/mapper/data  /mnt/data/media               btrfs rw,nodev,noatime,compress=zstd:3,ssd,discard,space_cache=v2,subvol=@media 0 0" >> /etc/fstab
echo "/dev/mapper/data  /mnt/data/UAF-data            btrfs rw,nodev,noatime,compress=zstd:3,ssd,discard,space_cache=v2,subvol=@UAF-data  0 0" >> /etc/fstab
echo "/dev/mapper/data  /mnt/data/media/photography   btrfs rw,nodev,noatime,compress=zstd:3,ssd,discard,space_cache=v2,subvol=@photography 0 0" >> /etc/fstab

systemctl daemon-reload
mount -a



# Create directory:
# Create media directory
mkdir -p /home/$USER/Pictures/{photography,meme,wallpaper,graphisme}
mkdir -p /home/$USER/Videos/{tvseries,movies,videos}
mkdir -p /home/$USER/Musics
mkdir -p /home/$USER/.thunderbird
mkdir -p /home/$USER/.local/share/baloo/
mkdir -p /home/$USER/.config/protonmail/bridge/cache 

# Disable COW for thunderbird, baloo, protonmail
chattr +C /home/$USER/.thunderbird
chattr +C /home/$USER/.local/share/baloo/
chattr +C /home/$USER/.cache/yay
chattr +C /home/$USER/.config/protonmail/


echo -e "... create yay subvolume for megavolts"
sudo rm -R /home/$NEWUSER/.cache/yay
sudo btrfs subvolume create /mnt/btrfs/data/@$NEWUSER
sudo btrfs subvolume create /mnt/btrfs/data/@$NEWUSER/@cache_yay
sudo btrfs subvolume create /mnt/btrfs/data/@$NEWUSER/@download


echo -e "... configure megavolts user directory"
cat << EOF >> /etc/fstab
## USER: megavolts
# yay cache
/dev/mapper/data  /home/$NEWUSER/.cache/yay  btrfs rw,nodev,noatime,nocow,compress=zstd:3,ssd,discard,space_cache=v2,subvol=/@$USER/@cache_yay 0 0"

# Download
/dev/mapper/data  /home/$NEWUSER/Downloads btrfs rw,nodev,noatime,compress=zstd:3,ssd,discard,clear_cache,nospace_cache,subvol=/@$USER/@download,uid=1000,gid=984,umask=022 0 0

# Media overlay
/mnt/data/media/musics      /home/$NEWUSER/Musics                fuse.bindfs     perms=0755,mirror-only=$NEWUSER 0 0
/mnt/data/media/photography /home/$NEWUSER/Pictures/photography  fuse,bindfs     perms=0755,mirror-only=$NEWUSER 0 0
/mnt/data/media/wallpaper   /home/$NEWUSER/Pictures/wallpaper    fuse,bindfs     perms=0755,mirror-only=$NEWUSER 0 0
/mnt/data/media/meme        /home/$NEWUSER/Pictures/meme         fuse,bindfs     perms=0755,mirror-only=$NEWUSER 0 0
/mnt/data/media/graphisme   /home/$NEWUSER/Pictures/graphisme    fuse,bindfs     perms=0755,mirror-only=$NEWUSER 0 0
/mnt/data/media/tvseries    /home/$NEWUSER/Videos/tvseries       fuse,bindfs     perms=0755,mirror-only=$NEWUSER 0 0
/mnt/data/media/movies      /home/$NEWUSER/Videos/movies         fuse,bindfs     perms=0755,mirror-only=$NEWUSER 0 0
/mnt/data/media/videos      /home/$NEWUSER/Videos/videos         fuse,bindfs     perms=0755,mirror-only=$NEWUSER 0 0
EOF

sudo systemctl daemon-reload && sudo mount -a

systemctl enable --now --user secretserviced.service 
sed -i '1s/^/"user_ssl_smtp": "false"/' .config/protonmail/bridge/prefs.json
gpg --batch --passphrase '' --quick-gen-key 'ProtonMail Bridge' default default never
pass init "ProtonMail Bridge"
protonmail-bridge --cli

## Configure SNAPPER

# Enable snapshots with snapper 
yay -S --noconfirm snapper snapper-gui-git snap-pac
echo -e "... >> Configure snapper"
snapper -c root create-config /

# we want the snaps located /at /mnt/btrfs-root/_snaptshot rather than at the root
btrfs subvolume delete /.snapshots

if [ -d "/home/.snapshots" ]
then
  rmdir /home/.snapshots
fi
snapper -c home create-config /home
btrfs subvolume delete /home/.snapshots

mkdir /.snapshots
mkdir /home/.snapshots

mount -o compress=zstd:3,subvol=@snapshots/@root_snaps /dev/mapper/arch /.snapshots
mount -o compress=zstd:3,subvol=@snapshots/@home_snaps /dev/mapper/arch /home/.snapshots

# Add entry in fstab
# echo "# Snapper subvolume" >> /etc/fstab # add snapper subvolume to fstab
echo "LABEL=arch /.snapshots btrfs rw,noatime,ssd,discard,compress=zstd:3,space_cache,subvol=@snapshots/@root_snaps   0 0" >> /etc/fstab
echo "LABEL=arch /home/.snapshots  btrfs rw,noatime,ssd,discardcompress=zstd:3,space_cache,subvol=@snapshots/@home_snaps   0 0" >> /etc/fstab

# echo "# Snapper subvolume" >> /etc/fstab # add snapper subvolume to fstab
sed "s/ALLOW_USERS=\"/ALLOW_USERS=\"$NEWUSER/g" -i /etc/snapper/configs/home # Allow $NEWUSER to modify the files
sed "s/ALLOW_USERS=\"/ALLOW_USERS=\"$NEWUSER/g" -i /etc/snapper/configs/root
sed "s/ALLOW_GROUPS=\"/ALLOW_GROUPS=\"wheel/g" -i /etc/snapper/configs/home # Allow $NEWUSER to modify the files
sed "s/ALLOW_GROUPS=\"/ALLOW_GROUPS=\"wheel/g" -i /etc/snapper/configs/root

sed "s/SYNC_ACL=\"no/SYNC_ACL=\"yes/g" -i /etc/snapper/configs/root
sed "s/SYNC_ACL=\"no/SYNC_ACL=\"yes/g" -i /etc/snapper/configs/root

sed 's/PRUNENAMES = "/PRUNENAMES = ".snapshots /g' -i /etc/updatedb.conf # do not index snapshot via mlocate

systemctl start snapper-timeline.timer snapper-cleanup.timer  # start and enable snapper
systemctl enable snapper-timeline.timer snapper-cleanup.timer

# Execute cleanup everyhour:
SYSTEMD_EDITOR=tee systemctl edit snapper-cleanup.timer <<EOF
[Timer]
OnUnitActiveSec=1h
EOF

# Execute snapshot every 5 minutes:
SYSTEMD_EDITOR=tee systemctl edit snapper-timeline.timer <<EOF
[Timer]
OnCalendar=*:0\/5/
EOF

setfacl -Rm "u:megavolts:rwx" /etc/snapper/configs
setfacl -Rdm "u:megavolts:rwx" /etc/snapper/configs

# update snap config for home directory
sed  "s|TIMELINE_MIN_AGE=\"1800\"|TIMELINE_MIN_AGE=\"1800\"|g" -i /etc/snapper/configs/home      # keep all backup for 2 days (172800 seconds)
sed  "s|TIMELINE_LIMIT_HOURLY=\"10\"|TIMELINE_LIMIT_HOURLY=\"96\"|g" -i /etc/snapper/configs/home  # keep hourly backup for 96 hours
sed  "s|TIMELINE_LIMIT_DAILY=\"10\"|TIMELINE_LIMIT_DAILY=\"14\"|g" -i /etc/snapper/configs/home    # keep daily backup for 14 days
sed  "s|TIMELINE_LIMIT_WEEKLY=\"0\"|TIMELINE_LIMIT_WEEKLY=\"0\"|g" -i /etc/snapper/configs/home    # do not keep weekly backup
sed  "s|TIMELINE_LIMIT_MONTHLY=\"10\"|TIMELINE_LIMIT_MONTHLY=\"12\"|g" -i /etc/snapper/configs/home # keep monthly backup for 12 months
sed  "s|TIMELINE_LIMIT_YEARLY=\"10\"|TIMELINE_LIMIT_YEARLY=\"5\"|g" -i /etc/snapper/configs/home   # keep yearly backup for 10 years

/etc/updatedb.conf
PRUNENAMES = ".snapshots"

# enable snapshot at boot
systemctl enable snapper-boot.timer

