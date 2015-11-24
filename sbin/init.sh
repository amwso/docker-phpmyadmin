#!/bin/bash

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
DATA_PATH=/data
LOG_FILE_PATH=$DATA_PATH/var/log
MYSQL_DATA_PATH=$DATA_PATH/mysql
WWW_DATA_PATH=$DATA_PATH/www
CONF_PATH=$DATA_PATH/conf
TEMP_PATH=$DATA_PATH/tmp
ARACRON_PATH=$DATA_PATH/var/spool/anacron
LOGROTATE_PATH=$DATA_PATH/var/lib/logrotate
PHP_SOCK_PATH=$DATA_PATH/var/run/php-fpm
WEBSHELL_DIR=$DATA_PATH/conf/webshell
WEBSHELL_CONF=$DATA_PATH/conf/nginx/nginx_site_webshell

mysql_init () {
	MYSQL_PASSWORD="${MYSQL_PASSWORD:-`pwgen -c -n -1 12`}"
	mkdir $MYSQL_DATA_PATH
	chown user_db:user_db $MYSQL_DATA_PATH
	mysql_install_db --defaults-file=/dev/null --datadir=$MYSQL_DATA_PATH --user=user_db
	mysqld --defaults-file=/dev/null --basedir=/usr --datadir=$MYSQL_DATA_PATH --log-error=/dev/null --user=user_db --pid-file=$MYSQL_DATA_PATH/mysqld.pid --socket=$MYSQL_DATA_PATH/mysqld.sock --skip-networking --plugin-dir=/usr/lib/mysql/plugin &
	
	# wait to start
	while ! mysqladmin -S $MYSQL_DATA_PATH/mysqld.sock ping >/dev/null 2>&1 ; do
		sleep 1
	done
	
	# change password, drop default db and user
	mysql -S $MYSQL_DATA_PATH/mysqld.sock -u root -e "DROP DATABASE IF EXISTS test; DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'; DELETE FROM mysql.user WHERE User=''; CREATE DATABASE IF NOT EXISTS user_db; GRANT ALL ON user_db.* to 'user_db'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD'; UPDATE mysql.user SET Password = PASSWORD('$MYSQL_PASSWORD') WHERE User = 'root'; GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '$MYSQL_PASSWORD' WITH GRANT OPTION; FLUSH PRIVILEGES;"
	echo $MYSQL_PASSWORD > $LOG_FILE_PATH/mysql-root-pw.txt
	chmod 0400 $LOG_FILE_PATH/mysql-root-pw.txt

	# shutdown mysql	
	kill -15 `cat $MYSQL_DATA_PATH/mysqld.pid` 2>/dev/null
	for i in 1 2 3 4 5 6 7 8 9 10; do
		kill -0 `cat $MYSQL_DATA_PATH/mysqld.pid` 2>/dev/null || break
		sleep 1
	done
	while kill -0 `cat $MYSQL_DATA_PATH/mysqld.pid` 2>/dev/null ; do
		kill -9 `cat $MYSQL_DATA_PATH/mysqld.pid` 2>/dev/null
		sleep 1
	done

}

check_dir () {
	# build dir
	[[ ! -d $LOG_FILE_PATH/supervisor ]] && mkdir -p $LOG_FILE_PATH/supervisor
	[[ ! -d $LOG_FILE_PATH/nginx ]] && mkdir -p $LOG_FILE_PATH/nginx
	[[ ! -d $LOG_FILE_PATH/php-fpm ]] && mkdir -p $LOG_FILE_PATH/php-fpm
	chown user_app $LOG_FILE_PATH/php-fpm
	[[ ! -d $LOG_FILE_PATH/mysql ]] && mkdir -p $LOG_FILE_PATH/mysql
	[[ ! -d $ARACRON_PATH ]] && mkdir -p $ARACRON_PATH
	[[ ! -d $LOGROTATE_PATH ]] && mkdir -p $LOGROTATE_PATH
	[[ ! -d $CONF_PATH ]] && cp -rf /root/template/conf $CONF_PATH
	diff -q /root/sbin/tools $DATA_PATH/tools > /dev/null || cp -rf /root/sbin/tools $DATA_PATH
	[[ ! -f $CONF_PATH/supervisor_service.conf ]] && cp -f /root/template/conf/supervisor_service.conf $CONF_PATH/supervisor_service.conf
	[[ ! -d $TEMP_PATH ]] && mkdir -p $TEMP_PATH
	chmod 1777 $TEMP_PATH
	[[ ! -d $TEMP_PATH/session ]] && mkdir -p $TEMP_PATH/session
	chmod 1733 $TEMP_PATH/session
	[[ ! -d $WWW_DATA_PATH ]] && mkdir $WWW_DATA_PATH && chown user_app:user_app $WWW_DATA_PATH
	[ "x$DOCKER_DISABLE_PMA" == "x" ] && [[ ! -h $WWW_DATA_PATH/pma ]] && ln -s /usr/share/phpmyadmin $WWW_DATA_PATH/pma
	[[ ! -d /var/run/mysqld ]] && mkdir /var/run/mysqld
	[[ ! -d /var/run/php-fpm ]] && mkdir /var/run/php-fpm
	[[ ! -d  $PHP_SOCK_PATH ]] && mkdir -p $PHP_SOCK_PATH
	#chown user_db /var/run/mysqld
	#[[ ! -d $MYSQL_DATA_PATH ]] && mysql_init
	
	# remove nginx socket
	[[ -e $LOG_FILE_PATH/nginx/site.sock ]] && rm $LOG_FILE_PATH/nginx/site.sock
}

install_webshell () {
	if [ "x$DOCKER_INSTALL_WEBSHELL" == "x" ] ; then
		:
	else
		[[ ! -d $WEBSHELL_DIR ]] && mkdir -p $WEBSHELL_DIR
		( cd /root/thirdparty/b374k-3.2.3 ; /usr/bin/php -f index.php -- -o $WEBSHELL_DIR/shell.php -p $DOCKER_INSTALL_WEBSHELL -s -b -z gzcompress -c 9 -t default )
		if [ -f ${WEBSHELL_CONF}.stop ] ; then
			mv ${WEBSHELL_CONF}.stop ${WEBSHELL_CONF}.conf
		fi
	fi
}

check_dir
install_webshell
# load crontab
crontab $CONF_PATH/crontab.root
# run anacron once
anacron -t $CONF_PATH/anacrontab -S $ARACRON_PATH -n -d

# Forward SIGTERM to supervisord process
_term() {
	while kill -0 $child >/dev/null 2>&1
	do
		kill -TERM $child 2>/dev/null
		sleep 1
	done
}
trap _term 15
exec /usr/bin/supervisord -n &
child=$!

wait $child
