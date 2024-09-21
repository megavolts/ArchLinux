# #/bin/bash!
# ssh megavolts@IP
# install graphic consol
# As user
 
# For all user
# enable audio for the user
echo -e ".. enable sound for $USR"
systemctl enable --user --now pipewire
systemctl enable --user --now pipewire-pulse

echo -e ".. create noCOW directory for $USER"
# Create noCOW directory
balooctl6 disable
rm -R /home/$USER/{.thunderbird,.local/share/baloo,.config/protonmail/bridge/cache}
mkdir -p /home/$USER/{.thunderbird,.local/share/baloo,.config/protonmail/bridge/cache}
# Disable COW for thunderbird, baloo, protonmail
chattr +C /home/$USER/.thunderbird
chattr +C /home/$USER/.local/share/baloo/
chattr +C /home/$USER/.config/protonmail/

echo -e "... create noCOW subvolume for yay"
sudo rm -R /home/$USER/.cache/yay
sudo mkdir /home/$USER/.cache/yay
sudo chattr +C /home/$USER/.cache/yay
sudo btrfs subvolume create /mnt/btrfs/root/@${USER}
sudo btrfs subvolume create /mnt/btrfs/root/@${USER}/@cache_yay
sudo mount -o rw,nodev,noatime,compress=zstd:3,ssd,discard,clear_cache,nospace_cache,nodatacow,commit=120,uid=1000,gid=984,umask=022,subvol=@${USER}/@cache_yay /dev/mapper/arch /home/${USER}/.cache/yay
sudo cat <<EOF | sudo tee -a /etc/fstab > /dev/null
## USER: megavolts
# yay cache
/dev/mapper/root  /home/${USER}/.cache/yay  btrfs rw,nodev,noatime,compress=zstd:3,ssd,discard,clear_cache,nospace_cache,nodatacow,commit=120,uid=1000,gid=984,umask=022,subvol=@${USER}/@cache_yay 0 0
EOF

echo -e "... create noCOW subvolume for Download"
sudo btrfs subvolume create /mnt/btrfs/root/@${USER}/@downloads
sudo cat <<EOF | sudo tee -a /etc/fstab > /dev/null
# Download
/dev/mapper/root  /home/${USER}/Downloads btrfs rw,nodev,noatime,compress=zstd:3,ssd,discard,clear_cache,nospace_cache,nodatacow,commit=120,uid=1000,gid=984,umask=022, subvol=/@${USER}/@downloads 0 0
EOF

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

echo -e "... configure megavolts user directory"
sudo cat <<EOF | sudo tee -a /etc/fstab > /dev/null
# Media overlay
/mnt/data/media/musics      /home/$USER/Musics                fuse.bindfs     perms=0755,mirror-only=$USER 0 0
/mnt/data/media/photography /home/$USER/Pictures/photography  fuse,bindfs     perms=0755,mirror-only=$USER 0 0
/mnt/data/media/wallpaper   /home/$USER/Pictures/wallpaper    fuse,bindfs     perms=0755,mirror-only=$USER 0 0
/mnt/data/media/meme        /home/$USER/Pictures/meme         fuse,bindfs     perms=0755,mirror-only=$USER 0 0
/mnt/data/media/graphisme   /home/$USER/Pictures/graphisme    fuse,bindfs     perms=0755,mirror-only=$USER 0 0
/mnt/data/media/tvseries    /home/$USER/Videos/tvseries       fuse,bindfs     perms=0755,mirror-only=$USER 0 0
/mnt/data/media/movies      /home/$USER/Videos/movies         fuse,bindfs     perms=0755,mirror-only=$USER 0 0
/mnt/data/media/videos      /home/$USER/Videos/videos         fuse,bindfs     perms=0755,mirror-only=$USER 0 0
EOF
sudo systemctl daemon-reload && sudo mount -a

yay -S --noconfirm gpgfrontend kwalletcli pinentry
gpg --refresh-keys
echo -e "... Don't forget to import key via gpg --import KEY"

echo -e "... configure protonmail bridge"
systemctl enable --now --user secretserviced.service 
# #sed -i '1s/^/"user_ssl_smtp": "false"/' ~/.config/protonmail/bridge/prefs.json
# gpg --batch --passphrase '' --quick-gen-key 'ProtonMail Bridge' default default never
# pass init "ProtonMail Bridge"
# protonmail-bridge --cli

# Set remote desktop
yay -S krfb krdc freerdp

yay -S flatpak flatpak-kcm flatseal
# Set up back in time
yay -S backintime

# Enable ssh agent for session
yay -S ksshaskpass
echo -e ".. Have SSH agents storing keys"
# echo "AddKeysToAgent yes" >> .ssh/config
# echo 'SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"' > ~/.config/environment.d/ssh_auth_socket.conf
systemctl --user enable --now ssh-agent


# Docker and install
echo -e "Install docker"
yay -S docker docker-compose
sudo systemctl enable --now docker
sudo gpasswd -a $USER docker
sudo cat <<EOF | sudo tee -a /etc/environment > /dev/null
DOCKERDIR=/opt/docker
APPDATA=/opt/docker/appdata
EOF
source /etc/environment
mkdir -p {$DOCKERDIR,$APPDATA}
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

yay -S --noconfirm kwalletmanager


echo -e ".. KDE dialog box"
# echo "GTK_USE_PORTAL=1" >> .config/environment.d/qt_style.conf
# echo "QT_STYLE_OVERRIDE=adwaita" >> .config/environment.d/qt_style.conf
# echo "QT_QPA_PLATFORMTHEME=qt5ct" >> .config/environment.d/qt_style.conf

# echo "KWallet login"
# echo "auth            optional        pam_kwallet5.so" >> /etc/pam.d/sddm
# echo "session         optional        pam_kwallet5.so auto_start" >> /etc/pam.d/sddm

echo -e << EOF
Don't forget:
- In firefox, to modify aboutc:config with browser.tabs.inTitlebar to 0 to enable maximize/minimize button

EOF

echo -e ".. Zoom screen sharing under wayland"
sed -i 's|enableWaylandShare=false|enableWaylandShare=true|g' ~/.config/zoomus.conf


[ ] REMOTE DESKTOP SET UP WITH KRFB


## TO TAKE CARE OFF
