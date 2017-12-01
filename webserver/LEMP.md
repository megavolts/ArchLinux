# Install a LEMP (Linux, Nginx, MariaDb, PHp) on Archlinux

## MariaDB
```
pacman -S mariadb
mysql_install_db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
```
Start the service
```
systemctl start mariadb
```
Configure mariadb
```
mysql_secure_installation
```
Then restart and enable mariadb
```
systemctl restart mariadb
systemctl enable mariadb
```

## Nginx Web Server
```
yaourt -S nginx
```
Try and enable nginx on success
```
systemctl start nginx
systemctl enbalbe nginx
```
To confirm, that nginx is runnign, access the nginx webserver through the ip address given with
```
curl -s icanhazip.com
```

## PHP-FPM
```
pacman -S php-fpm
systemctl start php-fpm
```
Modify nginx server block to run php using php-fpm
```
nano /etc/nginx/nginx.conf
--------------------------------------------------------------------------------------------------------------------------------------
location ~ \.php$ {
      fastcgi_pass   unix:/var/run/php-fpm/php-fpm.sock;
      fastcgi_index  index.php;
      root   /srv/http;
      include        fastcgi.conf;
 }

```
### Create a PHP info page
```
sudo nano /srv/http/info.php
--------------------------------------------------------------------------------------------------------------------------------------
<?php
phpinfo();
?>
```
Restart nginx
```
systemctl restart nginx
```



