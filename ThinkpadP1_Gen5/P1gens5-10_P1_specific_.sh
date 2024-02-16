 

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