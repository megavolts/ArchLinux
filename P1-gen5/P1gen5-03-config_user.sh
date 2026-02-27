# #/bin/bash!
# ssh megavolts@IP
# install graphic consol
# Run as USER
echo 'Enter '$USER ' passwords'
stty -echo
read PASSWORD

# Create noCOW directory
rm -R /home/$USER/{.thunderbird,.mozilla,.local/share/baloo,.config/protonmail/bridge/cache}
mkdir -p /home/$USER/{.thunderbird,.mozilla,.local/share/baloo,.config/protonmail/bridge/cache}
# Disable COW for thunderbird, baloo, protonmail
chattr +C /home/$USER/.thunderbird
chattr +C /home/$USER/.local/share/baloo/
chattr +C /home/$USER/.mozilla
chattr +C /home/$USER/.config/protonmail/

# Create noCOW yay build subvolume under .cache/yay
echo -e "... create noCOW subvolume for yay"
doas rm -R /home/$USER/.cache/yay
mkdir /home/$USER/.cache/yay
chattr +C /home/$USER/.cache/yay
if  ! [ -d /storage/btrfs/data/@${USER} ]; then
  doas btrfs subvolume create /storage/btrfs/data/@${USER}
fi
if [ -d /stroage/btrfs/data/@{USER}/@cache_yay ]; then
  doas btrfs subvolume delete /storage/btrfs/data/@$USER/@cache_yay
fi
doas btrfs subvolume create /storage/btrfs/data/@${USER}/@cache_yay

if ! [ -d /mnt/btrfs/data/@${USER}/@download ] ; then
  doas btrfs subvolume create /storage/btrfs/data/@${USER}/@downloads
fi
cat <<EOF | doas tee -a /etc/fstab > /dev/null
## USER: megavolts
### yay cache
LABEL=data  /home/$USER/.cache/yay  btrfs rw,nodev,noatime,compress=zstd,clear_cache,nospace_cache,nodatacow,commit=120,subvol=/@${USER}/@cache_yay 0 0
LABEL=data  /home/$USER/Downloads   btrfs rw,nodev,noatime,compress=zstd,clear_cache,nospace_cache,nodatacow,subvol=@${USER}/@downloads 0 0
EOF
mkdir -p /home/$USER/Downloads 
doas systemctl daemon-reload
doas mount -a

# Tailscale
yay -S trayscale

# For all user
# enable audio for the user
echo -e ".. enable sound for $USER"
systemctl enable --user --now pipewire
#systemctl enable --user --now pipewire-pulse

# For USER megavolts
# Import private gpg
echo -e "Importing private gpg key. Please select the correct file"
KEYFILE=$(kdialog --getopenfilename)
gpg --allow-secret-key-import --import $KEYFILE
gpg --refresh-keys


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
if [ !  -e /storage/btrfs/data/@media ]; then
  doas btrfs subvolume create /storage/btrfs/data/@media 
fi
if [ !  -e /storage/btrfs/data/@photography ]; then
  doas btrfs subvolume create /storage/btrfs/data/@photography
fi
if [ !  -e /storage/btrfs/data/@UAF-data ]; then
  doas btrfs subvolume create /storage/btrfs/data/@UAF-data
fi
mkdir -p /storage/data/{media,UAF-data}
mkdir -p /storage/data/media/{photography,wallpaper,meme,graphisme,tvseries,movies,videos,musics}
cat <<EOF | doas tee -a /etc/fstab > /dev/null
## Generic media
LABEL=data 	/storage/data/media				btrfs	rw,defaults,nodev,noatime,compress=zstd,subvol=@media	0 	0
LABEL=data 	/storage/data/UAF-data			btrfs	rw,defaults,nodev,noatime,compress=zstd,subvol=@UAF-data	0 	0
LABEL=data 	/storage/data/media/photography	btrfs	rw,defaults,nodev,noatime,compress=zstd,subvol=@photography	0 	0
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
doas systemctl daemon-reload && mount -a


# Protonmail
echo -e "... configure protonmail bridge"
yay -S --noconfirm protonmail-bridge protonvpn-gui 
protonmail-bridge &

# Set up oh-my-zsh
yay -S --noconfirm oh-my-zsh-git

# Set up git global
echo -e "... configure global variable for git"
git config --global user.email "marc.oggier@megavolts.ch"
git config --global user.name "Marc Oggier"

# Enable sshagent for session
echo -e ".. Enable SSH agents for session"
yay -S ksshaskpass
# echo "AddKeysToAgent yes" >> .ssh/config
# echo 'SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"' > ~/.config/environment.d/ssh_auth_socket.conf
systemctl --user enable --now ssh-agent

# Set up back in time
# echo -e "... set up secondary backup system"
# yay -S --noconfirm backintime

echo -e "... tuning firefox"
echo -e "Arkenfox setup"

echo -e "... force KDE dialog box everywhere"
mkdir ~/.config/systemd/user/xdg-desktop-portal.service.d
cat <<EOF | tee -a ~/.config/systemd/user/xdg-desktop-portal.service.d/override.conf > /dev/null
[Service]
Environment="XDG_CURRENT_DESKTOP=KDE"
EOF

# Docker and install
echo -e "Install docker"
yay -S docker docker-compose
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
git clone clone git@github.com:megavolts/adguard.git
chmod +x adguard/init.sh
./adguard/init.sh

sudo cat <<EOF | sudo tee -a /etc/resolv.conf.head > /dev/null
127.0.0.1
10.147.17.153
10.147.17.8
EOF

# echo "GTK_USE_PORTAL=1" >> .config/environment.d/qt_style.conf
# echo "QT_STYLE_OVERRIDE=adwaita" >> .config/environment.d/qt_style.conf
# echo "QT_QPA_PLATFORMTHEME=qt5ct" >> .config/environment.d/qt_style.conf

echo -e "... enable screen sharing for zoom with wayland"
if [ -f ~/.config/zoomus.conf ];
then
  sed -i 's|enableWaylandShare=false|enableWaylandShare=true|g' ~/.config/zoomus.conf
fi