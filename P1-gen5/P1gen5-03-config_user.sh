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
#systemctl enable --user --now pipewire-pulse

echo -e ".. create noCOW directory for $USER"
balooctl6 disable

# Create noCOW directory
rm -R /home/$USER/{.thunderbird,.mozilla,.local/share/baloo,.config/protonmail/bridge/cache}
mkdir -p /home/$USER/{.thunderbird,.mozilla,.local/share/baloo,.config/protonmail/bridge/cache}

# Disable COW for thunderbird, baloo, protonmail
chattr +C /home/$USER/.thunderbird
chattr +C /home/$USER/.local/share/baloo/
chattr +C /home/$USER/.mozilla
chattr +C /home/$USER/.config/protonmail/

echo -e "... create noCOW subvolume for yay"
sudo rm -R /home/$USER/.cache/yay
mkdir /home/$USER/.cache/yay
chattr +C /home/$USER/.cache/yay
sudo btrfs subvolume create /storage/btrfs/data/@${USER}
sudo btrfs subvolume create /storage/btrfs/data/@${USER}/@cache_yay
sudo cat <<EOF | sudo tee -a /etc/fstab > /dev/null

## USER: megavolts
# yay cache
LABEL=data  /home/$USER/.cache/yay  btrfs rw,nodev,noatime,compress=zstd,clear_cache,nospace_cache,nodatacow,commit=120,subvol=/@${USER}/@cache_yay 0 0
EOF

echo -e "... create noCOW subvolume for Download"
if ! [ -d /mnt/btrfs/data/@${USER}/@download ] ; then
	sudo btrfs subvolume create /storage/btrfs/data/@${USER}/@download
else
	echo "@download subvolume already exists"
fi
sudo cat <<EOF | sudo tee -a /etc/fstab > /dev/null
### Downloads
LABEL=data     /home/megavolts/Downloads  btrfs rw,nodev,noatime,compress=zstd,clear_cache,nospace_cache,nodatacow,subvol=@megavolts/@downloads 0 0
EOF

# For user megavolts:
# fix access for user megavolts to /opt and /mnt/data
sudo setfacl -Rm "u:${USER}:rwx" /opt
sudo setfacl -Rdm "u:${USER}:rwx" /opt
sudo setfacl -Rm "u:${USER}:rwx" /storage/data
sudo setfacl -Rdm "u:${USER}:rwx" /storage/data

# Create media directory
mkdir -p /home/$USER/Pictures/{photography,meme,wallpaper,graphisme}
mkdir -p /home/$USER/Videos/{tvseries,movies,videos}
mkdir -p /home/$USER/Musics

# BTRFS data subvolume
echo -e ".. create media subvolume on data and mount"
if [ !  -e /storage/btrfs/data/@media ]; then
  btrfs subvolume create /storage/btrfs/data/@media 
fi
if [ !  -e /storage/btrfs/data/@photography ]; then
  btrfs subvolume create /storage/btrfs/data/@photography
fi
if [ !  -e /storage/btrfs/data/@UAF-data ]; then
  btrfs subvolume create /storage/btrfs/data/@UAF-data
fi
mkdir -p /storage/data/{media,UAF-data}
mkdir -p /storage/data/media/{photography,wallpaper,meme,graphisme,tvseries,movies,videos,musics}
sudo cat <<EOF | sudo tee -a /etc/fstab > /dev/null
## Generic media
LABEL=data 	/storage/data/media				btrfs	rw,defaults,nodev,noatime,compress=zstd,subvol=@media	0 	0
LABEL=data 	/storage/data/UAF-data			btrfs	rw,defaults,nodev,noatime,compress=zstd,subvol=@UAF-data	0 	0
LABEL=data 	/storage/data/media/photography	btrfs	rw,defaults,nodev,noatime,compress=zstd,subvol=@photography	0 	0
EOF

echo -e "... configure megavolts user directory"
sudo cat <<EOF | sudo tee -a /etc/fstab > /dev/null
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
sudo systemctl daemon-reload && sudo mount -a

yay -S --noconfirm gpgfrontend kwalletcli pinentry
gpg --refresh-keys
echo -e "... Don't forget to import key via  gpg --allow-secret-key-import --import KEY"

echo -e "... configure protonmail bridge"
yay -S --noconfirm protonmail-bridge protonvpn-gui kwalletmanager
#systemctl enable --now --user secretserviced.service 
# sed -i '1s/^/"user_ssl_smtp": "false"/' .config/protonmail/bridge/prefs.json
# gpg --batch --passphrase '' --quick-gen-key 'ProtonMail Bridge' default default never
# pass init "ProtonMail Bridge"
protonmail-bridge --cli

# Set up oh-my-zsh
yay -S --noconfirm oh-my-zsh-git

# Set up git global
git config --global user.email "marc.oggier@megavolts.ch"
git config --global user.name "Marc Oggier"

# Enable sshagent for session
yay -S ksshaskpas
echo -e ".. Have SSH agents storing keys"
# echo "AddKeysToAgent yes" >> .ssh/config
# echo 'SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"' > ~/.config/environment.d/ssh_auth_socket.conf
systemctl --user enable --now ssh-agent


# Set up back in time
yay -S --noconfirm backintime

echo -e "Arkenfox setup"


# # sudo cat <<EOF | sudo tee -a /home/$USR/.config/environment.d/ssh_agent.conf > /dev/null
# # if ! pgrep -u "$USER" ssh-agent > /dev/null; then
# #     ssh-agent -t 2h > "$XDG_RUNTIME_DIR/ssh-agent.env"
# # fi
# # if [[ ! -f "$SSH_AUTH_SOCK" ]]; then
# #     source "$XDG_RUNTIME_DIR/ssh-agent.env" >/dev/null
# # fi
# # EOF

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

# yay -S --noconfirm kwalletmanager


echo -e ".. KDE dialog box"
mkdir ~/.config/systemd/user/xdg-desktop-portal.service.d
cat <<EFO | tee -a ~/.config/systemd/user/xdg-desktop-portal.service.d/override.conf > /dev/null
[Service]
Environment="XDG_CURRENT_DESKTOP=KDE"
EOF

# echo "GTK_USE_PORTAL=1" >> .config/environment.d/qt_style.conf
# echo "QT_STYLE_OVERRIDE=adwaita" >> .config/environment.d/qt_style.conf
# echo "QT_QPA_PLATFORMTHEME=qt5ct" >> .config/environment.d/qt_style.conf


# # TO CHECK IF NEEDED

# echo "KWallet login"
# echo "auth            optional        pam_kwallet5.so" >> /etc/pam.d/sddm
# echo "session         optional        pam_kwallet5.so auto_start" >> /etc/pam.d/sddm


# echo -e ".. Zoom screen sharing under wayland"
# sed -i 's|enableWaylandShare=false|enableWaylandShare=true|g' ~/.config/zoomus.conf


# [ ] REMOTE DESKTOP SET UP WITH KRFB



# # Set remote desktop
# yay -S krfb krdc freerdp

# yay -S flatpak flatpak-kcm flatseal
