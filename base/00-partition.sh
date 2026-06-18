# /bin/bash
# 16/06/2026
# Lenovo X1 Yoga Gen 6
# - with 4TB SSD disk
# - Dual boot with windows
#
# While installing windows, the partition scheme is created using the `diskpart` utility tool:
# (1) Launch command prompt with shift-F10
# (2) Run `diskpart`
# (3) Display and select disk using `list disk`, followed by `select disk X` where X refers to the corret
# (4) Prepare the disk using `clean`, followed by `convert gpt`
# (5a) Create EFI system partition with `create partition efi size=1024`
# (5b) Format EFI partition `format fs=fat32 quick label="EFI"`
# (6) Create Microsoft Reserved Partition using `create parition msr size=16`
# (7a) Create Microsfot Windows Parition `create partition primary size=262144`
# (7b) Format Microsoft Windows Partition to ntfs `format fs=ntfs quick label="Windows"
# (7c) Assign drive letter `Assign letter=W`
# (8a) Create Recovery Partition `create partition primary size=512`
# (8b) Format Recovery Partition to ntfs `format fs=ntfs quick label="Recovery"`
# (8c) Assign drive letter `Assign letter=R`
# (9) List volume: `list volume`
# To configure windows without internet access with local signin, launch command `OOBE\BYPASSNRO` within the command prompt - accessible via shift+F10 -
#
# Partititon table `sgdisk -p /dev/nvme0n1`
# Number  Start (sector)    End (sector)  Size       Code  Name
#   1            2048        16582655   7.9 GiB     EF00  EFI system partition
#   2        16582656        16615423   16.0 MiB    0C01  Microsoft reserved ...
#   3        16615424       539002879   249.1 GiB   0700  Basic data partition
#   4       539002880       540051455   512.0 MiB   0700  RECOVERY
#   5       540051456      5129682943   2.1 TiB     8300  CRYPTROOT
#   6      5129682944      7814035455   1.2 TiB     0700  PHOTOGRAPHY
# btrfs with flat layout: /, /var/

TODO tune to read conf file from config/X1.yaml
read -r HOSTNAME NEWUSER < <(yq '.hostname, .user' config/X1YogaG6.yaml)

HOSTNAME=dahu
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

echo -e "DISKS PREPARATION"
echo -e "ROOT partition"
if $NEWINSTALL
then
  echo ".. New installation, create new partition table"
  sgdisk -n $ROOTPART:540051456:5129682943 -t $ROOTPART:8300 -c $ROOTPART:"CRYPTROOT" $NUXDISK

  echo -e "... Wipe root partition"
  # Wipe partition with zeros after creating an encrypted container with a random key
  cryptsetup open --type plain ${NUXDISK}p${NUXROOTPART} container --key-file /dev/urandom 

  dd if =/dev/zero of=/dev/mapper/container status=progress bs=1M
  cryptsetup close container
  echo -e "... Encrypt root device"
  echo -en $PASSWORD | cryptsetup luksFormat ${NUXDISK}p${NUXROOTPART} -q
  echo -e "... Decrypt root device"
  echo -en $PASSWORD | cryptsetup luksOpen /dev/disk/by-partlabel/CRYPTROOT root
  mkfs.btrfs --force --label root /dev/mapper/root
else
  echo -e "... Decrypt root device"
  echo -en $PASSWORD | cryptsetup luksOpen ${NUXDISK}p${NUXROOTPART} root
  mkdir -p /mnt
  mount /dev/mapper/root /mnt
  if [ -d /mnt/@ ]; then
    mv /mnt/@ /mnt/@.$(date +%Y%m%d)
  fi
  umount /mnt
fi

echo -e "EFI partition"
if $NEWINSTALL
  # Remove OLD Limine Entry
  mount ${NUXDISK}p${NUXROOTPART} /mnt
  umount /mnt
fi

echo -e ".. Mount root btrfs subvolume on /mnt"
mount -o defaults,compress=zstd,noatime,nodev /dev/mapper/root /mnt/

if $WIPEROOT; then
  btrfs subvolume delete  /mnt/{@var_log,@var_cache,@root}
  if [ -d /mnt/@snapshots/ ]; then
  echo -e "... Delete individual root snapshots on  @root_snaps"
  btrfs subvolume delete /mnt/@snapshots/@root_snaps/*/snapshot 
  btrfs subvolume delete /mnt/@snapshots/@root_snaps/
  btrfs subvolume delete /mnt/root/@snapshots/
  fi  
fi

echo -e "... Create new root, var on root subvolume"
btrfs subvolume create /mnt/@ # Root directory
btrfs subvolume create /mnt/@var_log # Log files; avoid rollback for easier debugging
btrfs subvolume create /mnt/@var_cache # Cache files; no need to rollback
btrfs subvolume create /mnt/@root  # Root user's home directory
echo -e "... Unmount root btrfs subvolume from /mnt"
umount /mnt

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

echo -e "... mount root btrfs subvolume on /storage/btrfs/root"
mount -o defaults,compress=zstd,noatime,nodev /dev/mapper/root /mnt/storage/btrfs/root
