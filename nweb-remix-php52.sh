#get current working dir
cwd=$(pwd)
www=/var/www/default-www

#setup apt stable
echo "APT::Default-Release \"stable\";" >> /etc/apt/apt.conf
echo "deb http://http.us.debian.org/debian/ testing main contrib non-free" >> /etc/apt/sources.list
echo "deb-src http://http.us.debian.org/debian/ testing main contrib non-free" >> /etc/apt/sources.list
apt-get -y update

#TODO: fix restart screen that comes up for cron
#Configuring libpam0g
#configur libc6
apt-get -y upgrade

#nginx 0.7.65 should be
apt-get -t testing -y install nginx

#my apps
apt-get -y -t testing install htop less git-core rsync

#edit nginx.conf HERE
cp -f $cwd/conf/nginx.conf /etc/nginx/nginx.conf
cp -f $cwd/conf/default-www /etc/nginx/sites-enabled/
#delete default
rm /etc/nginx/sites-enabled/default

#config nginx, prepend params
echo 'fastcgi_connect_timeout 60;
fastcgi_send_timeout 180;
fastcgi_read_timeout 180;
fastcgi_buffer_size 32k;
fastcgi_buffers 512 32k;
fastcgi_busy_buffers_size 256k;
fastcgi_temp_file_write_size 256k;
fastcgi_intercept_errors on;' >> /tmp/fastcgitmp
cat /etc/nginx/fastcgi_params >> /tmp/fastcgitmp
cp /tmp/fastcgitmp /etc/nginx/fastcgi_params

#make www directory for nginx
mkdir -p $www/{public,private,log}
touch $www/log/access.log
touch $www/log/error.log

#install stuff to build php
#TODO: libc6 requires cron restart
apt-get -y -t testing install make bison flex gcc patch autoconf subversion locate
apt-get -y -t testing install libxml2-dev libbz2-dev libpcre3-dev libssl-dev zlib1g-dev libmcrypt-dev libmhash-dev libmhash2 libcurl4-openssl-dev libpq-dev libpq5

cd /usr/local/src/
wget http://us2.php.net/get/php-5.2.13.tar.gz/from/us.php.net/mirror
tar zxvf php-5.2.13.tar.gz
wget http://php-fpm.org/downloads/php-5.2.13-fpm-0.5.14.diff.gz
gzip -cd php-5.2.13-fpm-0.5.14.diff.gz | sudo patch -d php-5.2.13 -p1
cd php-5.2.13
./configure --enable-fastcgi --enable-fpm --with-mcrypt --with-zlib --enable-mbstring --disable-pdo --with-pgsql --with-curl --disable-debug --enable-pic --disable-rpath --enable-inline-optimization --with-bz2 --with-xml --with-zlib --enable-sockets --enable-sysvsem --enable-sysvshm --enable-pcntl --enable-mbregex --with-mhash --enable-xslt --enable-zip --with-pcre-regex
make all install
strip /usr/local/bin/php-cgi

#TODO fix stupid options
pecl install apc-beta

#move apc build files to useful locations
#WARNING maybe break if build changes?
cp /usr/local/lib/php/apc.php $www/public/apc.php
cp /usr/local/lib/php/extensions/no-debug-non-zts-20060613/apc.so /usr/local/lib/php/extensions/apc.so

mkdir /etc/php/
cp /usr/local/src/php-5.2.13/php.ini-recommended /usr/local/lib/php.ini
ln -s /usr/local/etc/php-fpm.conf /etc/php/php-fpm.conf

#sed edit-in-place doesnt work with file links
sed -i -r 's/^memory_limit.*/memory_limit = 64M/g' /usr/local/lib/php.ini
sed -i -r 's/^extension_dir.*/extension_dir = \/usr\/local\/lib\/php\/extensions\//g' /usr/local/lib/php.ini
ln -s /usr/local/lib/php.ini /etc/php/php.ini

#edit php.ini, enable apc
echo "extension=apc.so" >> /etc/php/php.ini
echo "apc.enabled = 1" >> /etc/php/php.ini
echo "apc.enable_cli = 1" >> /etc/php/php.ini
echo "apc.stat = 0" >> /etc/php/php.ini

#edit php-fpm.ini HERE
cp -f $cwd/conf/php-fpm.conf /etc/php/php-fpm.conf

#linux network tweaks for more connections
#TEMPORARY, this will be reset after reboot
#echo 30 > /proc/sys/net/ipv4/tcp_fin_timeout
#echo 30 > /proc/sys/net/ipv4/tcp_keepalive_intvl
#echo 5 > /proc/sys/net/ipv4/tcp_keepalive_probes
#echo 1 > /proc/sys/net/ipv4/tcp_tw_reuse
ulimit -n 50000

#setup test page to verify it works
echo "<?php phpinfo(); ?>" > $www/public/index.php

#run things
export PATH=/usr/local/sbin:$PATH
php-fpm start
/etc/init.d/nginx start