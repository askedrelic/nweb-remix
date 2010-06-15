#setup apt testing
echo "APT::Default-Release \"testing\";" >> /etc/apt/apt.conf
echo "deb http://http.us.debian.org/debian/ testing main contrib non-free" >> /etc/apt/sources.list
echo "deb-src http://http.us.debian.org/debian/ testing main contrib non-free" >> /etc/apt/sources.list
apt-get -y update
#TODO: fix restart screen that comes up for cron
apt-get -y upgrade

#Configuring libpam0g
#configur libc6

#nginx 0.7.65 should be
apt-get -t testing -y install nginx

apt-get -y -t testing install htop less git-core rsync

#edit nginx.conf HERE
cat > /etc/nginx/nginx.conf <<heredoc
user www-data;
worker_processes  4;
worker_rlimit_nofile 30000;

error_log  /var/log/nginx/error.log;
pid        /var/run/nginx.pid;

events {
    worker_connections  4096;
}

http {
    include       /etc/nginx/mime.types;

    access_log  /var/log/nginx/access.log;

    sendfile        on;

    keepalive_timeout  5;
    tcp_nodelay        on;

    gzip  on;
    gzip_disable "MSIE [1-6]\.(?!.*SV1)";

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
heredoc

cat > /etc/nginx/sites-enabled/default <<heredoc
server {
    listen   80;
    server_name  _;
    root   /var/www;
    index  index.php index.html index.htm;

    location ~ \.php\$ {
             fastcgi_pass   127.0.0.1:9000;
             fastcgi_index  index.php;
             fastcgi_param  SCRIPT_FILENAME  \$document_root\$fastcgi_script_name;
             include        fastcgi_params;
    }
}
heredoc

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
mkdir -p /var/www/

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

#has stupid options
pecl install apc-beta

#move apc build files to useful locations
#WARNING maybe break if build changes?
cp /usr/local/lib/php/apc.php /var/www/apc.php
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
cat > /etc/php/php-fpm.conf <<heredoc
<?xml version="1.0" ?>
<configuration>

    All relative paths in this config are relative to php's install prefix

    <section name="global_options">

        Pid file
        <value name="pid_file">/usr/local/logs/php-fpm.pid</value>

        Error log file
        <value name="error_log">/usr/local/logs/php-fpm.log</value>

        Log level
        <value name="log_level">notice</value>

        When this amount of php processes exited with SIGSEGV or SIGBUS ...
        <value name="emergency_restart_threshold">10</value>

        ... in a less than this interval of time, a graceful restart will be initiated.
        Useful to work around accidental curruptions in accelerator's shared memory.
        <value name="emergency_restart_interval">1m</value>

        Time limit on waiting child's reaction on signals from master
        <value name="process_control_timeout">5s</value>

        Set to 'no' to debug fpm
        <value name="daemonize">yes</value>

    </section>

    <workers>

        <section name="pool">

            Name of pool. Used in logs and stats.
            <value name="name">default</value>

            Address to accept fastcgi requests on.
            Valid syntax is 'ip.ad.re.ss:port' or just 'port' or '/path/to/unix/socket'
            <value name="listen_address">127.0.0.1:9000</value>

            <value name="listen_options">

                Set listen(2) backlog
                <value name="backlog">-1</value>

                Set permissions for unix socket, if one used.
                In Linux read/write permissions must be set in order to allow connections from web server.
                Many BSD-derrived systems allow connections regardless of permissions.
                <value name="owner">www-data</value>
                <value name="group">www-data</value>
                <value name="mode">0666</value>
            </value>

            Additional php.ini defines, specific to this pool of workers.
            <value name="php_defines">
        <!--        <value name="sendmail_path">/usr/sbin/sendmail -t -i</value>        -->
        <!--        <value name="display_errors">0</value>                              -->
            </value>

            Unix user of processes
            <value name="user">www-data</value>

            Unix group of processes
            <value name="group">www-data</value>

            Process manager settings
            <value name="pm">

                Sets style of controling worker process count.
                Valid values are 'static' and 'apache-like'
                <value name="style">static</value>

                Sets the limit on the number of simultaneous requests that will be served.
                Equivalent to Apache MaxClients directive.
                Equivalent to PHP_FCGI_CHILDREN environment in original php.fcgi
                Used with any pm_style.
                <value name="max_children">32</value>

                Settings group for 'apache-like' pm style
                <value name="apache_like">

                    Sets the number of server processes created on startup.
                    Used only when 'apache-like' pm_style is selected
                    <value name="StartServers">20</value>

                    Sets the desired minimum number of idle server processes.
                    Used only when 'apache-like' pm_style is selected
                    <value name="MinSpareServers">5</value>

                    Sets the desired maximum number of idle server processes.
                    Used only when 'apache-like' pm_style is selected
                    <value name="MaxSpareServers">35</value>

                </value>

            </value>

            The timeout (in seconds) for serving a single request after which the worker process will be terminated
            Should be used when 'max_execution_time' ini option does not stop script execution for some reason
            '0s' means 'off'
            <value name="request_terminate_timeout">0s</value>

            The timeout (in seconds) for serving of single request after which a php backtrace will be dumped to slow.log file
            '0s' means 'off'
            <value name="request_slowlog_timeout">0s</value>

            The log file for slow requests
            <value name="slowlog">logs/slow.log</value>

            Set open file desc rlimit
            <value name="rlimit_files">4096</value>

            Set max core size rlimit
            <value name="rlimit_core">0</value>

            Chroot to this directory at the start, absolute path
            <value name="chroot"></value>

            Chdir to this directory at the start, absolute path
            <value name="chdir"></value>

            Redirect workers' stdout and stderr into main error log.
            If not set, they will be redirected to /dev/null, according to FastCGI specs
            <value name="catch_workers_output">yes</value>

            How much requests each process should execute before respawn.
            Useful to work around memory leaks in 3rd party libraries.
            For endless request processing please specify 0
            Equivalent to PHP_FCGI_MAX_REQUESTS
            <value name="max_requests">0</value>

            Comma separated list of ipv4 addresses of FastCGI clients that allowed to connect.
            Equivalent to FCGI_WEB_SERVER_ADDRS environment in original php.fcgi (5.2.2+)
            Makes sense only with AF_INET listening socket.
            <value name="allowed_clients">127.0.0.1</value>

            Pass environment variables like LD_LIBRARY_PATH
            All \$VARIABLEs are taken from current environment
            <value name="environment">
                <value name="HOSTNAME">\$HOSTNAME</value>
                <value name="PATH">/usr/local/bin:/usr/bin:/bin</value>
                <value name="TMP">/tmp</value>
                <value name="TMPDIR">/tmp</value>
                <value name="TEMP">/tmp</value>
                <value name="OSTYPE">\$OSTYPE</value>
                <value name="MACHTYPE">\$MACHTYPE</value>
                <value name="MALLOC_CHECK_">2</value>
            </value>
        </section>
    </workers>
</configuration>
heredoc

#linux network tweaks for more connections
#TEMPORARY, this will be reset after reboot
echo 30 > /proc/sys/net/ipv4/tcp_fin_timeout
echo 30 > /proc/sys/net/ipv4/tcp_keepalive_intvl
echo 5 > /proc/sys/net/ipv4/tcp_keepalive_probes
echo 1 > /proc/sys/net/ipv4/tcp_tw_reuse
ulimit -n 50000

#setup test page to verify it works
echo "<?php phpinfo(); ?>" > /var/www/index.php

#run things
export PATH=/usr/local/sbin:$PATH
php-fpm start
/etc/init.d/nginx start
