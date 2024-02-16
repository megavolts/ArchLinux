# #/bin/bash!
# ssh megavolts@IP
# install graphic consol
PASSWORD=$1
NEWUSER=$2
HOSTNAME=$3
NEWUSER=$USER
# For all user
# enable audio for the user
echo -e ".. enable sound for $USER"
systemctl enable --user --now pipewire
systemctl enable --user --now pipewire-pulse

echo -e ".. create noCOW directory for $USER"
# Create noCOW directory
mkdir -p /home/$USER/.thunderbird
mkdir -p /home/$USER/.local/share/baloo/
mkdir -p /home/$USER/.config/protonmail/bridge/cache 

# Disable COW for thunderbird, baloo, protonmail
chattr +C /home/$USER/.thunderbird
chattr +C /home/$USER/.local/share/baloo/
chattr +C /home/$USER/.config/protonmail/

echo -e "... create noCOW subvolume for yay"
sudo rm -R /home/$USER/.cache/yay
sudo mkdir /home/$USER/.cache/yay
sudo chattr +C /home/$USER/.cache/yay
sudo btrfs subvolume create /mnt/btrfs/data/@$USER
sudo btrfs subvolume create /mnt/btrfs/data/@$USER/@cache_yay
sudo mount -o rw,nodev,noatime,compress=zstd:3,ssd,discard,clear_cache,nospace_cache,nodatacow,commit=120,,uid=1000,gid=984,umask=022,subvol=/@$USER/@cache_yay /dev/mapper/data /home/$USER/.cache/yay
sudo cat <<EOF | sudo tee -a /etc/fstab > /dev/null
## USER: megavolts
# yay cache
/dev/mapper/data  /home/$USER/.cache/yay  b rw,nodev,noatime,compress=zstd:3,ssd,discard,clear_cache,nospace_cache,nodatacow,commit=120,,uid=1000,gid=984,umask=022,subvol=/@$USER/@cache_yay 0 0
EOF

echo -e "... create noCOW subvolume for Download"
sudo btrfs subvolume create /mnt/btrfs/data/@$USER/@download
sudo mount -o rw,nodev,noatime,compress=zstd:3,ssd,discard,clear_cache,nospace_cache,nodatacow,commit=120,subvol=/@$USER/@download,uid=1000,gid=984,umask=022 /dev/mapper/data /home/$USER/Downloads
sudo cat <<EOF | sudo tee -a /etc/fstab > /dev/null
# Download
/dev/mapper/data  /home/$USER/Downloads btrfs rw,nodev,noatime,compress=zstd:3,ssd,discard,clear_cache,nospace_cache,nodatacow,commit=120,subvol=/@$USER/@download,uid=1000,gid=984,umask=022 0 0
EOF

# For user megavolts:
# fix access for user megavolts to /opt and /mnt/data
setfacl -Rm "u:${NEWUSER}:rwx" /opt
setfacl -Rdm "u:${NEWUSER}:rwx" /opt
setfacl -Rm "u:${NEWUSER}:rwx" /mnt/data
setfacl -Rdm "u:${NEWUSER}:rwx" /mnt/data


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


echo -e "... configure protonmail bridge"
systemctl enable --now --user secretserviced.service 
sed -i '1s/^/"user_ssl_smtp": "false"/' .config/protonmail/bridge/prefs.json
gpg --batch --passphrase '' --quick-gen-key 'ProtonMail Bridge' default default never
pass init "ProtonMail Bridge"
protonmail-bridge --cli

# Set remote desktop
yay -S krfb krdc freerdp


yay -S flatpak flatpak-kcm flatseal
# Set up back in time
yay -S backintime

# Enable ssh agent for session
echo -e ".. Have SSH agents storing keys"
echo "AddKeysToAgent yes" >> .ssh/config
echo 'SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"' > ~/.config/environment.d/ssh_auth_socket.conf
systemctl --user enable --now ssh-agent

# sudo cat <<EOF | sudo tee -a /home/$USR/.config/environment.d/ssh_agent.conf > /dev/null
# if ! pgrep -u "$USER" ssh-agent > /dev/null; then
#     ssh-agent -t 2h > "$XDG_RUNTIME_DIR/ssh-agent.env"
# fi
# if [[ ! -f "$SSH_AUTH_SOCK" ]]; then
#     source "$XDG_RUNTIME_DIR/ssh-agent.env" >/dev/null
# fi
# EOF

# Docker and install
echo -e "Install docker"
yay -S docker docker-compose
sudo systemctl enable --now docker
sudo cat <<EOF | sudo tee -a /etc/environment > /dev/null
DOCKERDIR=/opt/docker
APPDATA=/opt/docker/appdata
EOF
source /etc/environment
mkdir {$DOCKERDIR,$APPDIR}
echo -e ".. Set swag"
cd $DOCKERDIR
git clone clone git@github.com:megavolts/swag.git
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

# set up zerotier-one
yays -S zerotier-one
# # TO CHECK IF NEEDED

# echo "KWallet login"
# echo "auth            optional        pam_kwallet5.so" >> /etc/pam.d/sddm
# echo "session         optional        pam_kwallet5.so auto_start" >> /etc/pam.d/sddm


[ ] REMOTE DESKTOP SET UP WITH KRFB
