# 4 Packages
# 4.1 Utility packages
```
yaourt -S gparted ntfs-3g exfat-utils mtools gpart
yaourt -S mlocate xorg-xkill
yaourt -S yakuake tmux
yaourt -S kdialog kfind
yaourt -S ttf-dejavu font-mathematica ttf-mathtype ttf-vista-fonts ttf-freefont ttf-inconsolata ttf-hack ttf-anonymous-pro ttf-freefont ttf-liberation
sudo updatedb
```
yaourt -S kwallet kwalletmanager

## 2.4.2 Internet
```
yaourt -S firefox thunderbird
```
Profile-sync-daemon (psd) is a tiny pseudo-daemon designed to manage browser profile(s) in tmpfs and to periodically sync back to the physical disc (HDD/SSD). This is accomplished by an innovative use of rsync to maintain synchronization between a tmpfs copy and media-bound backup of the browser profile(s). These features of psd leads to following benefits:
* Transparent user experience
* Reduced wear to physical drives, and
* Speed
To setup. first install the profile-sync-daemon package.
```
yaourt -S profile-sync-daemon
```
Run psd the first time which will create a configuration file at \$XDG_CONFIG_HOME/psd/psd.conf which contains all settings.
```
psd
```
Modifiy `.config/psd/psd.conf` accordingly to your web browser. To enable the use of overlayfs to improve sync speed and to use a smaller memory footprint. Do this in the USE_OVERLAYFS=“yes” variable. In order to use the OVERLAYFS feature, you will also need to give sudo permissions to psd-helper as follows (replace $USERNAME accordingly):
```
nano /etc/sudoers
...
$USERNAME ALL=(ALL) NOPASSWD: /usr/bin/psd-overlay-helper
...
```
Verify the working of configuration using the preview mode of psd:
```
psd p
```

## Network
```
yaourt -S arp-scan
sudo arp-scan -q -l --interface enp1s0 | grep 00:1e:c9:46:57:67 
```

## 4.2 Media
```
yaourt -S dolphin dolphin-plugins kio-extras okular spectacle kio-mtp-git
yaourt -S discount kdegraphics-mobipocket kdegraphics-thumbnailers kdesdk-thumbnailers raw-thumbnailer ffmpegthumbs
yaourt -S filezilla konsole 
yaourt -S nextcloud-client qownnotes
yaourt -S ark unrar unzip
```

gamin
```
yaourt -S libdvdcss ffmpeg mencoder mpd ario sonata gstreamer0.10-ugly-plugins pycddb
yaourt -S gst-plugins-base gst-plugins-good gst-libav gst-plugins-ugly gst-plugins-bad
```

### 4.2.1 Images
```
yaourt -S imagemagick guetzli
yaourt -S geeqie inkscape gimp
yarout -S digikam darktable
yaourt -S hugin hugin-hg panomatic
```
### 4.2.2 Music & video
```
yaourt -S vlc
yaourt -S plex-media-server-plexpass plex-media-player
systemctl start plexmediaserver
systemctl enable plexmediaserver
```

### 4.3.  printer & scan
yaourt -S cups foomatic-db foomatic-db-engine foomatic-db-nonfree
4
## 4.4 vbox
```
yaourt -S virtualbox virtualbox-guest-iso virtualbox-host-modules-arch
sudo usermod -G vboxusers megavolts
```

 
## 4.6 office
```
yaourt -S libreoffice mendeleydesktop
yaourt -S texmaker texlive-most
> all # Install all packages
yaourt -S ghostscript
yaourt -S aspell-fr aspell-en aspell-de hunspell-en hunspell-fr hunspell-de hyphen-en hyphen-en hyphen-de libmythes mythes-en mythes-fr libreoffice-extension-grammalecte-fr
```
## 4.7 coding
```
yaourt -S pycharm-community git
```
To install the text editor ```sublime```, import the gpg key and add the repository to pacman
```
curl -O https://download.sublimetext.com/sublimehq-pub.gpg
sudo pacman-key --add sublimehq-pub.gpg
sudo pacman-key --lsign-key 8A8F901A
rm sublimehq-pub.gpg
echo -e "\n[sublime-text]\nServer = https://download.sublimetext.com/arch/dev/x86_64" | sudo tee -a /etc/pacman.conf
```
Now we can install sublime-text as:
```
yaourt -S sublime-text/sublime-text
```

# usbbootgui
To access raspberry pi gpio via usb
```
yaourt -s devscript 
https://github.com/raspberrypi/usbbootgui
```

# setup git
```
yaourt install git
git config --global user.name "Marc Oggier"
git config --global user.email "Marc Oggier"
```
Set up a git directory
```
mkdir gitdir
cd gitdir
git init
yaourt -S arduino
```

## gpg Setup
We have already installed the gnupg package during the pacaur installation. We will first either import our already existing private keys(s) or create one.

Once We have our keys setup, edit keys to change trust level.

Once all keys are setup, we need to gpg-agent configuration file:

$ vim ~/.gnupg/gpg-agent.conf
..
enable-ssh-support
default-cache-ttl-ssh 10800
default-cache-ttl 10800
max-cache-ttl-ssh 10800
...
$

Also, add following to your .zshrc or .“bash”rc file. If you are using my zprezto setup, you already have this!

$ vim ~/.zshrc
...
# set GPG TTY
export GPG_TTY=$(tty)

# Refresh gpg-agent tty in case user switches into an X Session
gpg-connect-agent updatestartuptty /bye >/dev/null

# Set SSH to use gpg-agent
unset SSH_AGENT_PID
if [ "${gnupg_SSH_AUTH_SOCK_by:-0}" -ne $$ ]; then
  export SSH_AUTH_SOCK="/run/user/$UID/gnupg/S.gpg-agent.ssh"
fi
...
$

Now, simply start the following systemd sockets as user:

$ systemctl --user enable gpg-agent.socket
$ systemctl --user enable gpg-agent-ssh.socket
$ systemctl --user enable dirmngr.socket
$ systemctl --user enable gpg-agent-browser.socket
$
$ systemctl --user start gpg-agent.socket
$ systemctl --user start gpg-agent-ssh.socket
$ systemctl --user start dirmngr.socket
$ systemctl --user start gpg-agent-browser.socket

Finally add your ssh key to ssh agent.

$ ssh-add ~/.ssh/id_ed25519


## screen 

```
yaourt -S synergy
```
Get online activation code through cpp.sh/3mjw3
