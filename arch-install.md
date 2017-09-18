# Archlinux @ HPZ400

## 0. Computer Spec
### 0.1 Hard drives
2 x 1.5 To WD Green in raid for system (/dev/sda, /dev/sdc ==> /devmd126)
1 x 4 To SeaGate for storage
data storage backup @ mull in WRRB


## 1. Preins
### 1.1 prepare hard drive
#### 1.1.1 System
Prepare system drive for GRUB/GPT install
```
gdisk /dev/md126
```
Create following partition table
```
Number  Pat Type  FSType      Label     Size
1       Primary   BIOS/ef02   bios_grub 1.0 Mib
2       Primary   Linux/8300  boot      512.0 Mib
3       Primary   Linux/8300  root      200.0 Gib
4       Primary   Linux/8300  home      200.0 Gib
5       Primary   Linux/8300  data      996.8 Gib 
```

#### 1.1.2 Encrypt and mount root device with a password
```
cryptsetup -c aes-xts-plain64 -s 512 -h sha512 -i 5000 --use-random --verify-passphrase luksFormat /dev/md126p3
cryptsetup luksdump /dev/md126p3
cryptsetup luksOpen /dev/md126p3 root
```
Format root parititon
```
mkfs.ext4 /dev/mapper/root
```
Mount root partition
```
mount /dev/mapper/root /mnt
```

#### 1.1.3 Encrypt and mount home device with a file and a password
```
cryptsetup -c aes-xts-plain64 -s 512 -h sha512 -i 5000 --use-random --verify-passphrase luksFormat /dev/md126p4
cryptsetup luksdump /dev/md126p4
```
Create and add a keyfile
```
dd if=/dev/urandom of=/mnt/home.keyfile bs=512 count=4
cryptsetup luksAddKey /dev/md126p4 /mnt/home.keyfile
cryptsetup luksDump /dev/md126p4
```
Decrypt partition with keyfile
```
cryptsetup luksOpen /dev/md126p4 -d /mnt/home.keyfile home
```
Format root parititon
```
mkfs.ext4 /dev/mapper/home
```
Mount root partition
```
mkdir /mnt/home
mount /dev/mapper/home /mnt/home
```

###
