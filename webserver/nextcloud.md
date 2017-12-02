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

## Install NextClooud
```
yaourt -S nextcloud
```
Install a pacman hook to upgrade nextcloud database automatically when nextcloud is updated
```
wget https://raw.githubusercontent.com/megavolts/ArchLinux/master/webserver/scripts/nextcloud-update.hook -P /etc/pacman.d/hooks
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
    ...
    server_names_hash_bucket_size 64;
    include conf.d/*.conf;
    include sites-enabled/*;
    ...
}
```
Create a configuration file for nextcloud according to [link: https://docs.nextcloud.com/server/12/admin_manual/installation/nginx.html]. Modified files is available through:
```
wget LINK -P /etc/nginx/nginx.d/
```

## Default configuration
Create directory to hold owncloud data and apps
```
mkdir -p /mnt/data/www/nextcloud/{data, apps2}
chown http:http /mnt/data/www//nextcloud -R
chmod 700 /mnt/data/www/nextcloud/{data, apps2}
```
Copy default config file
```
cp /etc/webapps/nextcloud/config/config.sample.php /etc/webapps/nextcloud/config/config.php
```
And modify accordingly to the newly created folders
```
nano 
