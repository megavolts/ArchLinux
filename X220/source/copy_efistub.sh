#! /bin/bash
# /usr/share/megavolts/copy_efistub.sh
# copy vmlinuz and initramfs from /boot to /boot_efi to be backup up via snapper and btrbk

if [ -f /boot/vmlinuz-linux ]; then
	cp -af /boot/vmlinuz-linux /boot_efi/zen/vmlinuz.efi
	cp -af /boot/initramfs-linux.img /boot_efi/archlinux.img
	cp -af /boot/initramfs-linux-fallback.img /boot_efi/archlinux-fallback.img
fi
if [ -f /boot/vmlinuz-linux-zen ]; then
	cp -af /boot/vmlinuz-linux-zen /boot_efi/vmlinuz-zen.efi
	cp -af /boot/initramfs-linux-zen.img /boot_efi/archlinux-zen.img
	cp -af /boot/initramfs-linux-zen-fallback.img /boot_efi/archlinux-zen-fallback.img
fi


mkdir /boot_efi/EFI
cp -af /boot/refind_linux.conf /boot_efi
cp -aRf /boot/EFI/refind /boot_efi/EFI
cp -aRf /boot/EFI/tools /boot_efi/EFI

echo $(uname -r) >> /boot_efi/kernel.version
