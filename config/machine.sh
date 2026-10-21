


# Enable packet forwarding
# Do not forget to config firewall too
nano /etc/sysctl.d/30-ipforward.confg <<EOF
net.ipv4.ip_forward = 1
net.ipv4.conf.all.forwarding = 1
net.ipv6.conf.all.forwarding = 1
EOF
