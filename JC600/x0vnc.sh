
pacman -S --noconfirm tigervnc

# Create environment, config, and password files
su - kiska -c  vncserver <<EOF
113RoxieRd
113RoxieRd
113RoxieRd
y
113view
113view
EOF

su -kiska -c "vncserer -kill :2"



# Set up a user service to remotely control the desktop via x0vncserver
# As the user:
su kiska << EOF
113RoxieRd
EOF

mkdir -p /home/kiska/.config/systemd/user/
tee /home/kiska/.config/systemd/user/x0vncserver.service << EOF
[Unit]
Description=Remote desktop service (VNC)

[Service]
Type=simple
User=%i
# wait for login with your username & password
ExecStart=/usr/bin/x0vncserver -PAMService=login -PlainUsers=kiska -SecurityTypes=TLSPlain

[Install]
WantedBy=default.target
EOF

# start the service 
systemctl enable --user x0vncserver

echo -e ".. to log in, run \`vncviewer <IP_HOST>\`"
