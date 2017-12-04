# Install a LEMP (Linux, Nginx, MariaDb, PHp) on Archlinux

## 
```
apt-get install net-tools wget curl bash-completion
```

## MariaDB
```
apt-get install mariadb-server
```
Start the service
```
service mysql start
```
Configure mariadb
```
mysql
-------------------------------------------------------------------------------
MariaDB> use mysql;
MariaDB> update user set plugin='' where User='root';
MariaDB> flush privileges;
MariaDB> exit
```
And then secure mariadb by running
```
mysql_secure_installation
```
Enter mariadb, and check 
```
mysql -u root –p
-------------------------------------------------------------------------------
MariaDB [(none)]> show databases;
MariaDB [(none)]> exit
```

## Nginx Web Server
```
apt-get install nginx
```
Try and enable nginx on success
```
service nginx start
```
To confirm, that nginx is runnign, access the nginx webserver through the ip address given with
```
curl -s icanhazip.com
```
Then enable nginx at start
```
systemctl enable nginx
```

## PHP-FPM
```
apt-get install php-fpm php-mysql php-curl php-gd php-mcrypt php-mbstring
```
Start php-fpm and check status
```
service php7.0-fpm start
service php7.0-fpm status
```
On success, enable at startup
```
systemctl enable php7.0-fpm
```
Create a PHP info page:
```
echo "<?php phpinfo(); ?>" > /var/www/html/info.php
```
Modify nginx server block to run php using php-fpm
```
nano /etc/nginx/nginx.conf
--------------------------------------------------------------------------------------------------------------------------------------
location ~ \.php$ {
      include snippets/fastcgi-php.conf;
      fastcgi_pass unix:/run/php/php7.0-fpm.sock;    
}

```
### Create a PHP info page
```
sudo nano /usr/share/nginx/html/info.php
--------------------------------------------------------------------------------------------------------------------------------------
<?php
phpinfo();
?>
```
Restart nginx
```
systemctl restart nginx
```

### Install phpmyadmin
Install required packages
```
pacman -S phpmyadmin php-mcrypt
```
Enable module in php-fpm:
```
nano /etc/php/php.ini
--------------------------------------------------------------------------------------------------------------------------------------
[...]
extension=mcrypt.so
extension=mysqli.so
[...]
```
Modify nginx.conf
```
nano /etc/nginx/nginx.conf
--------------------------------------------------------------------------------------------------------------------------------------
location / {
 root /usr/share/nginx/html;
 index index.html index.htm index.php;
```
Link PhpMyAdmin folder to nginx/html
```
ln -s /usr/share/webapps/phpMyAdmin/ /usr/share/nginx/html/
systemctl restart nginx
systemctl restart php-fpm
```
Check IP/phpMyAdmin
