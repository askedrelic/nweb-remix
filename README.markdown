# nWeb Remix
A script to help setting up a Linux/Nginx/MySQL/PHP server.

Inspired by nWeb http://thehook.eu/tools/nweb/

## Usage
	sudo sh nweb-remix.sh
	
## Details
Designed for Debian 5.0 stable(lenny) while pulling the latest packages for nginx/mysql from testing and manually compiling PHP with FPM for FastCGI.

* install nginx 0.7x from deb testing
* install php 5.2.12 with php-fpm from source
* install APC from PEAR
* install mysql 5.1.47 from deb testing