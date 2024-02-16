
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


sudo yay -S rmlint shredder-rmlint

yay -S duperemove


yay -S c++utilities qtutilities
yay -S qtforkawesome syncthing syncthingtray


yays(){sudo -u megavolts yay -S --removemake --cleanafter --noconfirm $1}

ssh-eval



# add docker
yay docker docker-composes
sudo usermod -aG docker megavolts
sudo echo APPDATA=/opt/appdata >> /etc/environment
sudo echo DOCKERDIR=/opt/docker >> /etc/environment
mkdir /opt/{appdata,docker}
sudo setfacl -dm "u:megavotls:rwx" /opt/appdata
sudo setfacl -m "u:megavotls:rwx" /opt/appdata
sudo setfacl -dm "u:megavotls:rwx" /opt/docker
sudo setfacl -m "u:megavotls:rwx" /opt/docker


# BEES
# DEDEUPT:
#echo "BEESHOME=/home/$USER/.config/$USER/bees" >> .config/environment.d/bees.conf  
#source .config/environment.d/bees.conf 

# bees has to be at the root subvol, with UUID being rootsubvol UUID
# find UUID of disk BTRFS_NAME={arch,data}

for BTRFS_DEV in root mapper
do
  UUID=$(blkid -s UUID -o value /dev/mapper/$BTRFS_DEV)
  echo /dev/mapper/$BTRFS_DEV $UUID
  mkdir -p /var/lib/bees/$UUID
  mount /dev/disk/by-uuid/$UUID /var/lib/bees/$UUID -osubvol=/
  export BEES_$BTRFS_DEV=@beeshome-$BTRFS_DEV
  echo BEES_$BTRFS_DEV=@beeshome-$BTRFS_DEV >> /etc/environment/
  btrfs sub create /var/lib/bees/$UUID/BEES_$BTRFS_DEV
  truncate -s 1g /var/lib/bees/$UUID/BEES_$BTRFS_DEV/beeshash.dat
  chmod 700 /var/lib/bees/$UUID/BEES_$BTRFS_DEV/beeshash.dat

  cp /etc/bees/beesd.conf.sample /etc/bees/$BTRFS_DEV.conf
  sed -i "s/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/$UUID/g" /etc/bees/$BTRFS_DEV.conf
  echo "BESHOME=/var/lib/bees/$UUID/BEES_$BTRFS_DEV@g" >> /etc/bees/$BTRFS_DEV.conf
done

UUID=$(blkid -s UUID -o value /dev/mapper/$BTRFS_NAME)
mkdir -p /var/lib/bees/$UUID
mount /dev/disk/by-uuid/$UUID /var/lib/bees/$UUID -osubvol=/

export BEESHOME=@beeshome
btrfs sub create /var/lib/bees/$UUID/$BEESHOME
truncate -s 1g /var/lib/bees/$UUID/$BEESHOME/beeshash.dat
chmod 700 /var/lib/bees/$UUID/$BEESHOME/beeshash.dat