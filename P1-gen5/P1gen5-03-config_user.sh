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
rm -R /home/$USER/{.thunderbird,.local/share/baloo,.config/protonmail/bridge/cache}
mkdir -p /home/$USER/{.thunderbird,.local/share/baloo,.config/protonmail/bridge/cache}

# Disable COW for thunderbird, baloo, protonmail
chattr +C /home/$USER/.thunderbird
chattr +C /home/$USER/.local/share/baloo/
chattr +C /home/$USER/.config/protonmail/

echo -e "... create noCOW subvolume for yay"
sudo rm -R /home/$USER/.cache/yay
mkdir /home/$USER/.cache/yay
chattr +C /home/$USER/.cache/yay
sudo btrfs subvolume create /mnt/btrfs/data/@${USER}
sudo btrfs subvolume create /mnt/btrfs/data/@${USER}/@cache_yay
sudo cat <<EOF | sudo tee -a /etc/fstab > /dev/null

## USER: megavolts
# yay cache
LABEL=data  /home/$USER/.cache/yay  btrfs rw,nodev,noatime,compress=zstd:3,ssd,discard,clear_cache,nospace_cache,nodatacow,commit=120,subvol=/@${USER}/@cache_yay 0 0
EOF

echo -e "... create noCOW subvolume for Download"
if ! [ -d /mnt/btrfs/data/@${USER}/@download ] ; then
	sudo btrfs subvolume create /mnt/btrfs/data/@${USER}/@download
else
	echo "@download subvolume already exists"
fi
# For user megavolts:
# fix access for user megavolts to /opt and /mnt/data
sudo setfacl -Rm "u:${USER}:rwx" /opt
sudo setfacl -Rdm "u:${USER}:rwx" /opt
sudo setfacl -Rm "u:${USER}:rwx" /mnt/data
sudo setfacl -Rdm "u:${USER}:rwx" /mnt/data

# Create media directory
mkdir -p /home/$USER/Pictures/{photography,meme,wallpaper,graphisme}
mkdir -p /home/$USER/Videos/{tvseries,movies,videos}
mkdir -p /home/$USER/Musics

# BTRFS data subvolume
echo -e ".. create media subvolume on data and mount"
if [ !  -e /mnt/btrfs/data/@media ]; then
  btrfs subvolume create /mnt/btrfs/data/@media 
fi
if [ !  -e /mnt/btrfs/data/@photography ]; then
  btrfs subvolume create /mnt/btrfs/data/@photography
fi
if [ !  -e /mnt/btrfs/data/@UAF-data ]; then
  btrfs subvolume create /mnt/btrfs/data/@UAF-data
fi
mkdir -p /mnt/data/{media,UAF-data}
mkdir -p /mnt/data/media/{photography,wallpaper,meme,graphisme,tvseries,movies,videos,musics}
sudo cat <<EOF | sudo tee -a /etc/fstab > /dev/null
## Generic media
LABEL=data 	/mnt/data/media				btrfs	rw,defaults,nodev,noatime,compress=zstd:3,ssd,discard,space_cache=v2,subvol=@media	0 	0
LABEL=data 	/mnt/data/UAF-data			btrfs	rw,defaults,nodev,noatime,compress=zstd:3,ssd,discard,space_cache=v2,subvol=@UAF-data	0 	0
LABEL=data 	/mnt/data/media/photography	btrfs	rw,defaults,nodev,noatime,compress=zstd:3,ssd,discard,space_cache=v2,subvol=@photography	0 	0
EOF

echo -e "... configure megavolts user directory"
sudo cat <<EOF | sudo tee -a /etc/fstab > /dev/null
## Media overlay
/mnt/data/media/musics      /home/$USER/Musics                fuse.bindfs     perms=0644,mirror-only=$USER 0 0
/mnt/data/media/photography /home/$USER/Pictures/photography  fuse,bindfs     perms=0644,mirror-only=$USER 0 0
/mnt/data/media/wallpaper   /home/$USER/Pictures/wallpaper    fuse,bindfs     perms=0644,mirror-only=$USER 0 0
/mnt/data/media/meme        /home/$USER/Pictures/meme         fuse,bindfs     perms=0644,mirror-only=$USER 0 0
/mnt/data/media/graphisme   /home/$USER/Pictures/graphisme    fuse,bindfs     perms=0644,mirror-only=$USER 0 0
/mnt/data/media/tvseries    /home/$USER/Videos/tvseries       fuse,bindfs     perms=0644,mirror-only=$USER 0 0
/mnt/data/media/movies      /home/$USER/Videos/movies         fuse,bindfs     perms=0644,mirror-only=$USER 0 0
/mnt/data/media/videos      /home/$USER/Videos/videos         fuse,bindfs     perms=0644,mirror-only=$USER 0 0
EOF
sudo systemctl daemon-reload && sudo mount -a

yay -S gpgfrontend kwalletcli pinentry
gpg --refresh-keys
echo -e "... Don't forget to import key via gpg --import KEY"

echo -e "... configure protonmail bridge"
yay -S --noconfirm protonmail-bridge protonvpn-gui secret-service
systemctl enable --now --user secretserviced.service 
# sed -i '1s/^/"user_ssl_smtp": "false"/' .config/protonmail/bridge/prefs.json
# gpg --batch --passphrase '' --quick-gen-key 'ProtonMail Bridge' default default never
# pass init "ProtonMail Bridge"
protonmail-bridge --cli

# Set up back in time
yay -S --noconfirm backintime

echo -e << EOF
.. For Firefox
- widget.use-xdg-dekstop-portal-mime-handler: 1
- widget.user-xdg-dekstop-portal.file-picker: 1
- media.hardwaremediakeys.enabled: false
- browser.tabs.inTitlebar: 1
EOF


# Enable ssh agent for session
# yay -S ksshaskpass
# echo -e ".. Have SSH agents storing keys"
# # echo "AddKeysToAgent yes" >> .ssh/config
# # echo 'SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"' > ~/.config/environment.d/ssh_auth_socket.conf
# systemctl --user enable --now ssh-agent

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
