#!/bin/bash
set -e
set -o pipefail

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

cd /tmp

sudo -u user_app -- wp core download --path=/data/www --locale=zh_CN

sudo -u user_app -- wp core config --dbname=user_db --dbuser=user_db --dbpass=`cat /data/var/log/mysql-root-pw.txt` --dbhost=127.0.0.1 --dbprefix=wp_ --path=/data/www

cat >> /data/www/wp-config.php <<EOF

define( 'WP_HOME', 'http://' . \$_SERVER['HTTP_HOST'] );
define( 'WP_SITEURL', 'http://' . \$_SERVER['SERVER_HOST'] );
EOF

sudo -u user_app -- wp core install --url='http://' --title='hello world' --admin_user=${DOCKER_WP_ADMIN:-admin} --admin_password=${DOCKER_WP_PASSWORD:-password} --admin_email=admin@exmaple.com --path=/data/www

sudo -u user_app -- wp core language update --path=/data/www
