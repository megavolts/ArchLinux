# Nextcloud


## Install PHP modul for NextCloud
```
yaourt -S php-intl php-mcrypt
```
Uncomment the line
```
nano -w /etc/php/php.ini
--------------------------------------------------------------------------------------------------------------------------------------
extension=gd.so
extension=iconv.so
```
Uncomment the line
```
nano -w /etc/php/php-fpm.d/www.conf
--------------------------------------------------------------------------------------------------------------------------------------
env[PATH] = $HOSTNAME
env[PATH] = /usr/local/bin:/usr/bin:/bin
```

## Install NextCloud
Download the latest version of nextcloud in the webserver directory
```
cd /mnt/data/www/megavolts.ch
wget wget https://download.nextcloud.com/server/releases/nextcloud-10.0.1.tar.bz2
tar xvf nextcloud-10.0.1.tar.bz2
```
Fix the user and group for nginx

```
chown http:http extcloud/ -R
```

## Database setup
Change password for your own
```
mysql -u root -p
--------------------------------------------------------------------------------------------------------------------------------------
mysql> CREATE DATABASE `nextcloud` DEFAULT CHARACTER SET `utf8` COLLATE `utf8_unicode_ci`;
mysql> CREATE USER `nextcloud`@'localhost' IDENTIFIED BY 'password';
mysql> GRANT ALL PRIVILEGES ON `nextcloud`.* TO `nextcloud`@`localhost`;
mysql> \q
```

## Nginx webserver setup
Create an empty directory to hold cloud-specific configuration files
```
mkdir /etc/nginx/conf.d/
mkdir /etc/sites-enabled/
```
Modify nginx.conf
```
nano -w /etc/nginx/nginx.conf
--------------------------------------------------------------------------------------------------------------------------------------
http {
    include conf.d/*.conf;
    ...
}
```
Download the config file for the nextcloud server @ cloud.megavolts.ch
```
wget LINK -p /etc/nginx/conf.d/
```
Reload nginx:
```
systemctl reload nginx
```

