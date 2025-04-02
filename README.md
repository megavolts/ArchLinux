# Active computer
## Thinkpad P1 Gen5
- eth0 MAC ${{ secrets.P1GEN5_MAC_ETH0}}
- wlan0 MAC ${{ secrets.P1GEN5_MAC_WIFI}}
- Thinkpad X1 Yoga Gen6

# Retired computer
- HP Z400
- Thinkpad X220


# Installation
Boot from archlinux usb boot drive.

## Connection to wireless access point:
To connect to a wireless access point, get an  `iwctl` interactive prompt:

`$ iwctl`

And then connect the interface dev0 to ESSID wireless access point, use

`[iwd]# station *dev0* connect SSID`

Follow any prompot to configure the connection correctly.

## SSH connection
First, set up root password with:

`passwd`

Restart the sshd daemon:

`systemctl restart sshd`

Connect via ssh, and procede to installation according to correct configuration
