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
    include conf.d/*.conf;
    ...
}
```
Add the following line at the end of the configuration files
```
/etc/webapps/nextcloud/config/config.php
--------------------------------------------------------------------------------------------------------------------------------------
'apps_paths' =>
  array (
    0 =>
    array (
      'path' => '/usr/share/webapps/nextcloud/apps',
      'url' => '/apps',
      'writable' => false,
    ),
    1 =>
    array (
      'path' => '/usr/share/webapps/nextcloud/apps2',
      'url' => '/apps2',
      'writable' => true,
    ),
  ),
  'datadirectory' => '/usr/share/webapps/nextcloud/data'
```
Create the directories and, link accordingly
```
mkdir -p /mnt/data/www/nextcloud/{data, apps2}
chown http:http /mnt/data/www//nextcloud -R
chmod 700 /mnt/data/www/nextcloud/{data
chmod 700 /mnt/data/www/nextcloud/apps
ln -s /mnt/data/www/nextcloud/data /usr/share/webapps/nextcloud/data
ln -s /mnt/data/www/nextcloud/apps /usr/share/webapps/nextcloud/app2
```
Log to cloud.megagavolts.ch and finish the configuration


