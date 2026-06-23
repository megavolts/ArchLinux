# #/bin/bash!
# ssh megavolts@IP
# install graphic consol
# Run as USER
echo 'Enter '$USER ' passwords'
stty -echo
read PASSWORD


# For all user
# enable audio for the user
echo -e ".. enable sound for $USER"
systemctl enable --user --now pipewire

# For MegaVolts
# Set megavolts as tailnet user
doas tailscale set --operator=$USER

# Import private gpg
echo -e "Importing private gpg key. Please select the correct file"
KEYFILE=$(kdialog --getopenfilename)
gpg --allow-secret-key-import --import $KEYFILE
gpg --refresh-keys

# Tune BTRFS for user
echo -e ".. create noCOW directory for $USER"
balooctl6 disable

# Create noCOW directory
rm -Rf /home/$USER/{.thunderbird,.mozilla,.local/share/baloo,.config/protonmail/bridge/cache}
mkdir -p /home/$USER/{.thunderbird,.mozilla,.local/share/baloo,.config/protonmail/bridge/cache}

# Disable COW for thunderbird, baloo, protonmail
chattr +C /home/$USER/.thunderbird
chattr +C /home/$USER/.local/share/baloo/
chattr +C /home/$USER/.mozilla
chattr +C /home/$USER/.config/protonmail/bridge/cache/

# Create noCOW yay build subvolume under .cache/yay
echo -e "... create noCOW subvolume for yay"
doas rm -R /home/$USER/.cache/yay
mkdir /home/$USER/.cache/yay
chattr +C /home/$USER/.cache/yay
if [[ "$(cat /etc/hostname)" == "vouivre" ]]; then
  BTRFS_SUBVOL=data
else
  BTRFS_SUBVOL=root
fi
if  ! [ -d /storage/btrfs/${BTRFS_SUBVOL}/@${USER} ]; then
  doas btrfs subvolume create /storage/btrfs/${BTRFS_SUBVOL}/@${USER}
fi
if [ -d /storage/btrfs/${BTRFS_SUBVOL}/@$USER/@cache_yay ]; then
  doas btrfs subvolume delete /storage/btrfs/$BTRFS_SUBVOL/@$USER/@cache_yay
fi
doas btrfs subvolume create /storage/btrfs/$BTRFS_SUBVOL/@${USER}/@cache_yay
if ! [ -d /storage/btrfs/$BTRFS_SUBVOL/@$USER/@downloads ] ; then
  doas btrfs subvolume create /storage/btrfs/$BTRFS_SUBVOL/@$USER/@downloads
fi
cat <<EOF | doas tee -a /etc/fstab > /dev/null
## USER: megavolts
### yay cache
/dev/mapper/${BTRFS_SUBVOL}  /home/$USER/.cache/yay  btrfs rw,nodev,noatime,compress=zstd,clear_cache,nospace_cache,nodatacow,commit=120,subvol=/@${USER}/@cache_yay 0 0
/dev/mapper/${BTRFS_SUBVOL}  /home/$USER/Downloads   btrfs rw,nodev,noatime,compress=zstd,clear_cache,nospace_cache,nodatacow,subvol=@${USER}/@downloads 0 0
EOF
mkdir -p /home/$USER/Downloads 
doas systemctl daemon-reload
doas mount -a

# Fix folder access
echo -e "Give access to megavolts to /opt and /storage/data"
doas setfacl -Rm "u:${USER}:rwx" /opt
doas setfacl -Rdm "u:${USER}:rwx" /opt
doas setfacl -Rm "u:${USER}:rwx" /storage/data
doas setfacl -Rdm "u:${USER}:rwx" /storage/data

echo -e "Create multimedia directory for megavolts"
mkdir -p /home/$USER/Pictures/{photography,meme,wallpaper,graphisme}
mkdir -p /home/$USER/Videos/{tvseries,movies,videos}
mkdir -p /home/$USER/Musics


# BTRFS data subvolume
echo -e ".. create media subvolume on data and mount"
if [ !  -e /storage/btrfs/${BTRFS_SUBVOL}/@media ]; then
  doas btrfs subvolume create /storage/btrfs/${BTRFS_SUBVOL}/@media 
fi
if [ !  -e /storage/btrfs/${BTRFS_SUBVOL}/@UAF-data ]; then
  doas btrfs subvolume create /storage/btrfs/${BTRFS_SUBVOL}/@UAF-data
fi
mkdir -p /storage/data/{media,UAF-data}
mkdir -p /storage/data/media/{photography,wallpaper,meme,graphisme,tvseries,movies,videos,musics}
cat <<EOF | doas tee -a /etc/fstab > /dev/null
## Generic media
/dev/mapper/${BTRFS_SUBVOL}   /storage/data/media       btrfs rw,defaults,nodev,noatime,compress=zstd,subvol=@media 0   0
/dev/mapper/${BTRFS_SUBVOL}   /storage/data/UAF-data      btrfs rw,defaults,nodev,noatime,compress=zstd,subvol=@UAF-data  0   0
EOF

if [[ "$(cat /etc/hostname)" == "vouivre" ]]; then
  if [ !  -e /storage/btrfs/${BTRFS_SUBVOL}/@photography ]; then
    doas btrfs subvolume create /storage/btrfs/${BTRFS_SUBVOL}/@photography
  fi
  cat <<EOF | doas tee -a /etc/fstab > /dev/null
/dev/mapper/${BTRFS_SUBVOL}  /storage/data/media/photography btrfs rw,defaults,nodev,noatime,compress=zstd,subvol=@photography 0   0
EOF
  echo -e "... configure megavolts user directory"
  cat <<EOF | doas tee -a /etc/fstab > /dev/null
## Media overlay
/storage/data/media/musics      /home/$USER/Musics                fuse.bindfs     perms=0644,mirror-only=$USER 0 0
/storage/data/media/photography /home/$USER/Pictures/photography  fuse.bindfs     perms=0644,mirror-only=$USER 0 0
/storage/data/media/wallpaper   /home/$USER/Pictures/wallpaper    fuse.bindfs     perms=0644,mirror-only=$USER 0 0
/storage/data/media/meme        /home/$USER/Pictures/meme         fuse.bindfs     perms=0644,mirror-only=$USER 0 0
/storage/data/media/graphisme   /home/$USER/Pictures/graphisme    fuse.bindfs     perms=0644,mirror-only=$USER 0 0
/storage/data/media/tvseries    /home/$USER/Videos/tvseries       fuse.bindfs     perms=0644,mirror-only=$USER 0 0
/storage/data/media/movies      /home/$USER/Videos/movies         fuse.bindfs     perms=0644,mirror-only=$USER 0 0
/storage/data/media/videos      /home/$USER/Videos/videos         fuse.bindfs     perms=0644,mirror-only=$USER 0 0
EOF

elif [[ "$(cat /etc/hostname)" == "dahu" ]]; then
  cat <<EOF | doas tee -a /etc/fstab > /dev/null
/dev/nvme0n1p6    /home/megavolts/Pictures/photography  ntfs    rw,uid=1000,gid=1000,dmask=022,fmask=133 0 0
EOF
fi
doas systemctl daemon-reload && mount -a

# Enroll Fingerprint
doas fprintd-enroll megavolts -f right-index-finger
doas fprintd-enroll megavolts -f right-middle-finger

# Set up git global
echo -e "... configure global variable for git"
git config --global user.email "marc.oggier@megavolts.ch"
git config --global user.name "Marc Oggier"

# # Set up kwallet to save ssh passphrae
# echo "AddKeysToAgent yes" >> ~/.ssh/config
# cat << EOF > ~/.config/environment.d/ssh_askpass.conf
# SSH_ASKPASS=/usr/bin/ksshaskpass
# SSH_ASKPASS_REQUIRE=prefer
# EOF
# cat << EOF > ~/.config/environment.d/git_askpass.conf
# # not required if SSH_ASKPASS is set to use ksshaskpass
# GIT_ASKPASS=/usr/bin/ksshaskpass
# EOF
# # Start ssh agent with systemd for user session
# echo -e ".. Enable SSH agents for session"
# cat << EOF > ~/.config/environment.d/ssh_auth_socket.conf
# SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"
# EOF

systemctl --user enable --now ssh-agent

# KDE Desktop
- Dropdown terminal Yakuake
  - META+spacebar shortcut
  - Set transparency to 33%
- Setup KDE desktop
  - Dark theme
  - Toolbar on top
  - Toolbar height set to 37px
- Startup
  - Yakuake
  - tail-tray
- Network
  - Set up UAF VPN with globalconnect, as currently networkmanager-openconnect does not work anymore
  - Set up eduroam with geteduroam
- EMail
  - configure protonmail-bridge
  - configure proton account
  - configure uaf account
- Shared file
  - Configure nextcloud-client
  - Configure UAF google account
- Firefox & Zen Browser
  - tune
#### BELOW IS OLD
#
#
# --------------------------------------------------------------------------------------------------------#



echo -e "... tuning firefox"
echo -e "Arkenfox setup"

# echo -e "... force KDE dialog box everywhere"
# mkdir ~/.config/systemd/user/xdg-desktop-portal.service.d
# cat <<EOF | tee -a ~/.config/systemd/user/xdg-desktop-portal.service.d/override.conf > /dev/null
# [Service]
# Environment="XDG_CURRENT_DESKTOP=KDE"
# EOF

# Docker and install
echo -e "Install docker"
yay -S docker docker-buildx
echo -e ".. add $USER to docker group"
sudo usermod -aG docker megavolts
sudo systemctl enable --now docker
sudo cat <<EOF | sudo tee -a /etc/environment > /dev/null
DOCKERDIR=/opt/docker
APPDATA=/opt/docker/appdata
EOF
source /etc/environment

mkdir -p {$DOCKERDIR,$APPDIR}
echo -e ".. Set swag"
cd $DOCKERDIR
git clone git@github.com:megavolts/swag.git
chmod +x swag/init.sh
./swag/init.sh

echo -e ".. Set adguard & unbound"
git clone git@github.com:megavolts/adguard.git
chmod +x adguard/init.sh
./adguard/init.sh

sudo cat <<EOF | sudo tee -a /etc/resolv.conf.head > /dev/null
127.0.0.1
10.147.17.153
10.147.17.8
EOF