#!/bin/bash
set -e
set -o pipefail

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
PW_FILE_PATH=/data/var/log/mysql-root-pw.txt
MY_CNF_PATH=/data/conf/my.cnf
DUMP_PATH=/data/db_dump
DATE_FORMAT=$(date +%Y-%m-%d-%H%M%S)

[[ ! -d $DUMP_PATH ]] && mkdir -p $DUMP_PATH

while read db ; do
	mysqldump --defaults-file=$MY_CNF_PATH -u root -p`cat $PW_FILE_PATH` --add-drop-table --single-transaction --max-allowed-packet=1024M $db | gzip > $DUMP_PATH/backup-${db}-$DATE_FORMAT.sql.gz
done < <(mysql -u root -p`cat /data/var/log/mysql-root-pw.txt` -Bse 'show databases'|egrep -vi '^information_schema$|^performance_schema$|^mysql$')

