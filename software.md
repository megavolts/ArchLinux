# 4 Packages
# 4.1 Utility packages
```
yaourt -S gparted ntfs-3g exfat-utils mtools gpart
pacman -S mlocate xorg-xkill
yaourt -S  tilda terminator
yaourt -S ttf-dejavu font-mathematica ttf-mathtype ttf-vista-fonts ttf-google-fonts-git ttf-freefont ttf-inconsolata
sudo updatedb
```


## 2.4.2 Internet
```
yaourt -S firefox thunderbird
```

## Network
```
yaourt -S arp-scan
sudo arp-scan -q -l --interface enp1s0 | grep 00:1e:c9:46:57:67 
```


## 4.2 Media
```
yaourt -S dolphin filezilla
```
yaourt -S ffmpegthumbnailer poppler-glib ligsf libopenraw
yaourt -S gvfs gvfs-smb sshfs udiskie fuse mtpfs gigolo gvfs-mtp gvfs-gphoto2  
yaourt -S xarchiver unrar p7zip unzip
yaourt -S imagemagick
yaourt -S libdvdcss ffmpeg mencoder mpd ario sonata gstreamer0.10-ugly-plugins pycddb
yaourt -S gst-plugins-base gst-plugins-good gst-libav gst-plugins-ugly gst-plugins-bad

### 4.2.1 Images
yaourt -S geeqie inkscape
yaourt -S gimp
yaourt -S hugin hugin-hg panomatic

### 4.2.2 Music & video
```
yaourt -S amarok vlc
```

### 4.3.  printer & scan
yaourt -S cups foomatic-db foomatic-db-engine foomatic-db-nonfree
yaourt -S xsane xsane-gimp

## 4.4 vbox
```
yaourt -S virtualbox virtualbox-guest-iso virtualbox-host-modules-arch
usermod -G vboxusers megavolts
```

## 4.5 customization
yaourt -S awoken-icons
 
## 4.6 office
yaourt -S acroread libreoffice mendeleydesktop zotero
yaourt -S texmaker texlive-most
> all # Install all packages
yaourt -S ghostscript
yaourt -S aspell-fr aspell-en aspell-de hunspell-en hunspell-fr hunspell-de hyphen-en hyphen-en hyphen-de libmythes mythes-en mythes-fr libreoffice-extension-grammalecte-fr

## 4.7 coding
```
yaourt -S pycharm-community git
yaourt -S sublime-text-dev
```
# 3.7.n mtp
yaourt -S mtpfs kio-mtp 


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
```
