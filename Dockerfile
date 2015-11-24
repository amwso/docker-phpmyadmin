FROM ubuntu:14.04
MAINTAINER HJay <trixism@qq.com>

# Let the conatiner know that there is no tty
ENV DEBIAN_FRONTEND noninteractive

RUN cp /root/.bashrc /root/.profile / ; \
 echo 'HISTFILE=/dev/null' >> /.bashrc ; \
 HISTSIZE=0 ; \
 echo 'deb http://archive.ubuntu.com/ubuntu/ trusty multiverse' >> /etc/apt/sources.list ; \
 echo 'deb-src http://archive.ubuntu.com/ubuntu/ trusty multiverse' >> /etc/apt/sources.list ; \
 apt-get update ; \
 apt-get -y upgrade ; \
 cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime ; \
 sed -i 's/UTC=yes/UTC=no/' /etc/default/rcS

RUN apt-get -y install nginx-extras \
 php5-cli php5-curl php5-fpm php5-json php5-mcrypt php5-mysql php5-sqlite php5-xmlrpc php5-xsl php5-gd php-apc \
 phpmyadmin \
 curl wget git unzip pwgen anacron \
 supervisor python-setuptools \
 mysql-server mysql-client ; \
 apt-get clean ; \
 easy_install mr.laforge ; \
 php5enmod mcrypt ; \
 echo root > /etc/cron.allow 

COPY ./sbin /root/sbin
COPY ./template /root/template
RUN mv /etc/supervisor/supervisord.conf /etc/supervisor/supervisord.conf.default ; \
 cp /root/template/conf/supervisord.conf /etc/supervisor/supervisord.conf ; \
 cp /root/template/conf/crontab /etc/crontab ; \
 cp /root/template/conf/cron.d/anacron /etc/cron.d/anacron ; \
 rm /etc/cron.d/php5

RUN \
 groupadd -g 5000 -r user_app ; \
 useradd -l -M -r  -s /usr/sbin/nologin -u 5000 -g 5000 user_app ; \
 groupadd -g 5001 -r user_db ; \
 useradd -l -M -r  -s /usr/sbin/nologin -u 5001 -g 5001 user_db ; \
 groupadd -g 5002 -r user_web ; \
 useradd -l -M -r  -s /usr/sbin/nologin -u 5002 -g 5002 user_web ; \
true

# webshell
RUN \
 mkdir -p /root/thirdparty ; \
 curl -sSL https://github.com/b374k/b374k/archive/v3.2.3.tar.gz | tar -zxf - -C /root/thirdparty/ ; \
 true

EXPOSE 80

CMD ["/bin/bash","/root/sbin/init.sh"]
