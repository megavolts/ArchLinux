
############################################################
NEWUSER=megavolts
WINDATAPART=/dev/disk/by-label/WinData
WINBOOTPART=/dev/disk/by-label/EFI
NUXBOOTPART=/dev/disk/by-label/EFIARCH

echo -e "As the new user"

############################################################
# ## Install liminie helper
# arch-chroot /mnt pacman -Ss --noconfirm gradle
# arch-chroot /mnt wget https://aur.archlinux.org/cgit/aur.git/snapshot/limine-mkinitcpio-hook.tar.gz
# arch-chroot /mnt tar -xvzf limine-mkinitcpio-hook.tar.gz -C /home/$NEWUSER
# arch-chroot /mnt chown ${NEWUSER}:users /home/$NEWUSER/limine-mkinitcpio-hook -R
# #mkdir /mnt/home/${NEWUSER}/.cache
# #arch-chroot /mnt chown ${NEWUSER}:users /home/$NEWUSER/.cache -R
# arch-chroot /mnt doas -u ${NEWUSER} bash -c "makepkg -s --noconfirm -D /home/$NEWUSER/limine-mkinitcpio-hook"
# arch-chroot /mnt bash -c "pacman -U --noconfirm /home/${NEWUSER}/yay/yay-*.zst"

yayc(){yay -S --removemake --cleanafter --noconfirm $1}

yayc  limine-mkinitcpio-hook
# TODO MORE
echo -e 

# # create a fake builduser
# buildpkg(){
#   CURRENT_DIR=$pwd
#   wget https://aur.archlinux.org/cgit/aur.git/snapshot/$1.tar.gz
#   tar -xvzf $1.tar.gz -C /home/$NEWUSER
#   chown ${NEWUSER}:users /home/$NEWUSER/$1 -R
#   doas -u $NEWUSER bash -c "makepkg -s --noconfirm -D /home/$NEWUSER/$1"
#   pacman -U --noconfirm /home/$NEWUSER/$1/$1*.zst
#   cd $CURRENT_dir
#   rm /home/$NEWUSER/$1/ -r
# }

# yays(){arch-chroot /mnt doas -u $NEWUSER bash -c "yay -S --removemake --cleanafter --noconfirm $1"}

############################################################
echo -e ".. sync older directory to new directory for $NEWUSER"
# {}
# # Sync old NEWUSER directory to new NEWUSER directory
# NEED TO MAKE SURE NO TO COPY hiddne file
# if [ -d /home/$NEWUSER-old ]; then
#   rsync -a /home/$NEWUSER-old/ /home/$NEWUSER/ -h --info=progress2 --remove-source-files
#   find /home/$NEWUSER-old -type d -empty -delete
# fi



## Install liminie helper
arch-chroot /mnt pacman -Ss --noconfirm gradle
yays  limine-mkinitcpio-hook limine-snapper-sync

cp /etc/limine-snapper-sync.conf /etc/default/limine
sed -i "s|#TARGET_OS_NAME=\"Arch Linux\"|TARGET_OS_NAME=\"Arch Linux\"|g"        /etc/default/limine
#sed -i "s|ROOT_SNAPSHOTS_PATH=\"\/@\/.snapshots\"|ROOT_SNAPSHOTS_PATH=\"\/@snapshots\/@root_snaps\"|g"        /etc/default/limine
sed -i "s|#ENABLE_NOTIFICATION=yes|ENABLE_NOTIFICATION=yes|g"        /etc/default/limine
sed -i "s|#AUTH_METHOD=\"run0 --background=\"|AUTH_METHOD=doas|g"    /etc/default/limine

cat >> /etc/default/limine << EOF
##############  Below options apply to original limine ##############

### Note: Editing this configuration file is not necessary. Instead, copy it to \`/etc/default/limine\` and configure it as needed.
### Settings in \`/etc/default/limine\` will override here.

### Skip UEFI Check and Registration
### Skip UEFI check and bootloader registration on certain non-compliant UEFI boards (e.g., some MSI boards) (yes|no)
### If skipped, Limine will be used as the fallback bootloader on the standard UEFI path for all UEFI systems.
### Note:
### When set to yes, run 'limine-install' and manually set the BIOS boot order to make the standard UEFI path the default boot.
#SKIP_UEFI=no


### Kernel Command Line Configuration
### Define one or more kernel command lines (parameters) for specific kernel entries.
### If unset, the tool will try to read them from '/etc/kernel/cmdline' or '/proc/cmdline'.
###
### Rules:
### * KERNEL_CMDLINE[default] applies to any kernel entries without specific configuration.
### * KERNEL_CMDLINE[fallback] applies to kernel entries with names containing *fallback*
### * KERNEL_CMDLINE[kernel name] applies to a specific kernel entry.
###
### Operators:
### * \`+=\` appends parameters to an existing cmdline for the same KERNEL_CMDLINE[<key>]
###    Commonly used in drop-in configs: /etc/limine-entry-tool.d/*.conf
###    Ignores /etc/kernel/cmdline and /proc/cmdline
### * \`=\` replaces an existing cmdline for the same KERNEL_CMDLINE[<key>]
###    Note: /etc/default/limine overrides any drop-in configs, so \`+=\` is recommended there.
###
### Tips:
### - If unsure which parameters to use, copy them from \`/proc/cmdline\` into KERNEL_CMDLINE[default],
###   but make sure your system is not a live ISO, temporary environment, or snapshot.
### - Multiple \`initrd=\` parameters are automatically converted into Limine module paths for non-UKI entries.
### - No quotes are needed at the start or end of command lines, since quotes inside are not escaped.
### - Do not add \`#\` as a comment at the end of command lines.
###
### Examples:
#KERNEL_CMDLINE[default]+=rw root=UUID=...
#KERNEL_CMDLINE[default]+=quiet splash acpi_osi="..."
#KERNEL_CMDLINE[default]+=initrd=/amd-ucode.img
#KERNEL_CMDLINE[fallback]=
#KERNEL_CMDLINE[linux-zen]=


### Boot Integrity Check
### Enable BLAKE2 checksum verification for bootable files. (yes|no)
ENABLE_VERIFICATION=yes


### Kernel Entries Order
### Wildcard "*" matches any letter in kernel entry name
### If ENABLE_SORT is set to "yes", only wildcard "*" entries are sorted alphabetically.
BOOT_ORDER="*, *fallback, Snapshots"
ENABLE_SORT=no


### Default Boot Fallback
### Configure whether Limine should be installed as the default UEFI fallback loader. (yes|no|"")
### This helps preserve bootability on UEFI systems where BIOS, firmware, or Windows updates may remove custom Linux UEFI entries.
###
### Options:
### * "yes"               -> Always create, update, or overwrite the fallback on each limine-update.
### * "no"                -> Do nothing.
### * "" or commented out -> Create the fallback only if it is not present. If a fallback exists, leave it untouched.
###
### Note:
### With Secure Boot enabled, the default fallback is not signed automatically by limine-update for some reason.
### If you need to sign it, it is recommended to disable ENABLE_LIMINE_FALLBACK, run 'limine-install --fallback' once,
### and then sign the fallback manually.
###
#ENABLE_LIMINE_FALLBACK=""


### Find Bootloaders
### Automatically add systemd-boot, rEFInd, or the default EFI loader to Limine if they are found in the ESP. (yes|no)
FIND_BOOTLOADERS=yes


### Enroll Limine Config
### Automatically embeds a checksum of the Limine config into the Limine binary to protect it against unauthorized modifications.
###
### WARNING:
### Enabling this will PREVENT booting if you modify limine.conf without re-enrolling it afterward.
###
### If you are unsure but want to try it, run 'limine-install --fallback' first.
### This allows you to boot into the Limine fallback if a boot panic occurs due to a config checksum mismatch.
###
### IMPORTANT:
### * After editing limine.conf, always run 'limine-enroll-config'
### * Remove all other Limine configs from alternative locations to avoid boot failures.
### * If using limine-snapper-sync, make sure you have:
###   - /etc/boot/hooks/pre.d/ with a symlink 10-limine-reset-enroll -> /usr/bin/limine-reset-enroll
###   - /etc/boot/hooks/post.d/ with a symlink 90-limine-enroll-config -> /usr/bin/limine-enroll-config
### * If multiple systems share the same limine.conf, ensure each system handles enrollment automatically.
###
### To enable, copy this option to /etc/default/limine and set it to (yes|no)
#ENABLE_ENROLL_LIMINE_CONFIG=no


##############  Below options apply to Arch Linux when 'limine-mkinitcpio-hook' is installed ##############

### UKI (Unified Kernel Image)
### Automatically create UKIs in '\$ESP_PATH/EFI/Linux/' using mkinitcpio for UEFI. (yes|no)
###
### Advantage:
###  - UKIs are automatically loaded by bootloaders like 'systemd-boot' and 'rEFInd'.
### Disadvantage:
###  - UKIs use more ESP space compared to separate 'initramfs' and 'vmlinuz' files, especially with multiple Limine snapshots.
###
### Additional notes:
### - Duplicate 'initramfs' and 'vmlinuz' files are removed when 'limine-mkinitcpio' or 'limine-update' is run to generate a UKI.
### - UKI ignores booting into a snapshot when Secure Boot is enabled. To resolve this, any embedded kernel cmdline is removed from the UKI, which will then read the external kernel cmdline.
ENABLE_UKI=yes

### mkinitcpio UKI Build Options
### Additional options for mkinitcpio UKI builds
### See: https://man.archlinux.org/man/mkinitcpio.8.en#OPTIONS_FOR_UNIFIED_KERNEL_IMAGE
### Example: Add a splash screen
MKINITCPIO_UKI_OPTIONS="--splash /usr/share/systemd/bootctl/splash-arch.bmp"

EOF
