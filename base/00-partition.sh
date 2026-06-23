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

# TODO tune to read conf file from config/X1.yaml
# read -r HOSTNAME NEWUSER < <(yq '.hostname, .user' config/X1YogaG6.yaml)

SSN=$(dmidecode -s system-serial-number)
if [[ $SSN == "PW04CDHX" ]]; then
  DUALBOOT=true
  echo "# P1 Vouivre"
  HOSTNAME=vouivre
  WINDISK=/dev/nvme1n1
  WINBOOTPART=1
  NUXDISK=/dev/nvme0n1
  NUXBOOTPART=1
  NUXROOTPART=2
  NUXDATAPART=3
  # TODO: check for win disk
elif [[ $SSN == "PF3EV1ZS" ]]; then
  # TODO: Read from config file
  DUALBOOT=true
  echo "# X1 Dahu"
  HOSTNAME=dahu
  WINDISK=/dev/nvme0n1
  NUXDISK=/dev/nvme0n1
  WINBOOTPART=1
  NUXBOOTPART=1
  NUXROOTPART=5
  NUXDATAPART=5
  NUXPHOTPART=6
fi

NEWUSER=megavolts
NEWINSTALL=false
WIPEROOT=true
WIPEDATA=false
NTFSDATA=false
TZDATA=America/Anchorage
NTFSDATA=false

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
  mount /dev/mapper/root /mnt
  if [ -d /mnt/@ ]; then
    mv /mnt/@ /mnt/@.$(date +%Y%m%d)
  fi
  rm /mnt/@swap/*
  umount /mnt
fi

echo -e "EFI partition"
if $DUALBOOT


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
  btrfs subvolume delete /mnt/@snapshots/
  fi  
fi

echo -e "... Create new root, var on root subvolume"
btrfs subvolume create /mnt/@ # Root directory
btrfs subvolume create /mnt/@var_log # Log files; avoid rollback for easier debugging
btrfs subvolume create /mnt/@var_cache # Cache files; no need to rollback
btrfs subvolume create /mnt/@root  # Root user's home directory

echo -e "... Unmount root btrfs subvolume from /mnt"
umount /mnt

