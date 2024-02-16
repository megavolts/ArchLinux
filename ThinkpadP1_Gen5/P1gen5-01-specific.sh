# #/bin/bash!
# ssh megavolts@IP
# install graphic consol
PASSWORD=$1
NEWUSER=$2
HOSTNAME=$3

echo -e ".. > Optimize mirrorlist"
pacman -S --noconfirm reflector"
systemctl enable --now reflector.timer
sed -i "s|# --country France,Germany|--country USA,Switzerland|g" /etc/xdg/reflector/reflector.conf

echo -e ".. install basic tools"
pacman -S --noconfirm mlocate acl util-linux fwupd

# update database
updatedb

# fix access for user megavolts to /opt
setfacl -Rm "u:${NEWUSER}:rwx" /opt
setfacl -Rdm "u:${NEWUSER}:rwx" /opt

# enable fstrim for ssd
systemctl enable --now fstrim.timer

## Graphical interface
echo -e "Graphic interface"
echo -e ".. Install drivers specific to Intel Corporation Alder Lake-P Integrated Graphics Controller"
pacman -S --noconfirm mesa vulkan-intel vulkan-mesa-layers
# Enable GuC/HuC firmware loading
echo "options i915 enable_guc=2" >> /etc/modprobe.d/i915.conf
mkinitcpio -p linux-zen 

echo -e ".. Install xorg and input"
yay -S --noconfirm xorg-server xorg-apps xorg-xinit xorg-xrandr xorg-xkill xorg-xauth
