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
```
Modify nginx.conf
```
nano -w /etc/nginx/nginx.conf
--------------------------------------------------------------------------------------------------------------------------------------
http {
    ...
    server_names_hash_bucket_size 64;
    include conf.d/*.conf;
    ...
}
```
Create a configuration file for nextcloud according to [link: https://docs.nextcloud.com/server/12/admin_manual/installation/nginx.html]. Modified files is available through:
```
wget LINK -P /etc/nginx/nginx.d/
```

