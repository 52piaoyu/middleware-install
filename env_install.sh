#!/bin/bash

set -e

curPath=$(cd $(dirname $0); pwd)

function Usage()
{
	echo "sh $0 MOUDLELIST[redis | nginx | postgres | caddy | mysql]"
	echo "eg: sh $0 redis"
	echo "    sh $0 nginx"
	echo "    sh $0 postgres"
	echo "    sh $0 caddy"
	echo "    sh $0 mysql"
}

function install_common()
{
	# make
	if [[ $(rpm -aq | grep make | grep -v grep) == "" ]];then
		yum -y install make
	fi
	
	#gcc
	if [[ $(rpm -aq | grep gcc | grep -v grep) == "" ]];then
		yum -y install gcc
	fi
	
	#pcre
	if [[ $(rpm -aq | grep pcre | grep -v grep) == "" ]];then
		yum -y install pcre
	fi
	if [[ $(rpm -aq | grep pcre-devel | grep -v grep) == "" ]];then
		yum -y install pcre-devel
	fi
	
	#zlib
	if [[ $(rpm -aq | grep zlib | grep -v grep) == "" ]];then
		yum -y install zlib
	fi
	if [[ $(rpm -aq | grep zlib-devel | grep -v grep) == "" ]];then
		yum -y install zlib-devel
	fi
	
	#openssl 
	if [[ $(rpm -aq | grep openssl  | grep -v grep) == "" ]];then
		yum -y install openssl 
	fi
	if [[ $(rpm -aq | grep openssl-devel | grep -v grep) == "" ]];then
		yum -y install openssl-devel
	fi
	
	#readline
	if [[ $(rpm -aq | grep readline  | grep -v grep) == "" ]];then
		yum -y install readline 
	fi
	if [[ $(rpm -aq | grep readline-devel | grep -v grep) == "" ]];then
		yum -y install readline-devel
	fi
	
	#psmisc
	if [[ $(rpm -aq | grep psmisc  | grep -v grep) == "" ]];then
		yum -y install psmisc 
	fi
}

function install_redis()
{
	file_redis_package="redis-4.0.7.tar.gz"
	file_redis_conf="redis.conf"
	file_redis_ctl="redis_ctl"
	redis_home="/usr/local/redis"
	redis_conf="/usr/local/redis/etc"
	redis_user="redis"
	redis_group="redis"
	redis_log="$redis_home/redis.log"

	#check if redis is installed
	if [[ $(ps -ef | grep redis | grep -v $0 | grep -v grep) == "" && $(whereis redis-server | awk -F ':' '{print $2}') == "" ]];then
		cd $curPath/redis
		if [[ -f "$file_redis_package" && -f "$file_redis_conf" ]];then
			rm -rf $redis_home
			mkdir -p $redis_home/bin
			mkdir -p $redis_conf 
			mkdir -p $redis_home/run
			cp -f $file_redis_conf $redis_conf && chmod 640 $redis_conf/$file_redis_conf
			cp -f $file_redis_ctl $redis_home/bin && chmod 750 $redis_home/bin/$file_redis_ctl
			touch $redis_log && chmod 640 $redis_log

			tar xvf $file_redis_package
			cd redis-4.0.7
			make MALLOC=libc && make PREFIX=$redis_home install

			#add redis user and group
			if ! grep "$redis_group" /etc/group > /dev/null;then
				groupadd $redis_group
			fi

			if ! grep "$redis_user" /etc/passwd > /dev/null;then
				useradd -M -s /sbin/nologin -g $redis_group $redis_user
			fi
			chown -R $redis_user:$redis_group $redis_home

			#add core param config
			sed -i "/^net.core.somaxconn/d" /etc/sysctl.conf
			echo 'net.core.somaxconn = 2048' >> /etc/sysctl.conf
			sysctl -p

			#start redis
			sudo -u $redis_user /usr/local/redis/bin/redis_ctl start
			return 0
		else
			echo "There is no redis file, please check!!"
			return 1
		fi

	else
		echo "Redis is installed，please check！！"
		return 1
	fi
}

function install_nginx()
{
	file_nginx_package="nginx-1.12.2.tar.gz"
	file_nginx_conf="nginx.conf"
	nginx_home="/usr/local/nginx"
	nginx_user="nginx"
	nginx_group="nginx"
	nginx_root_dir="/wwwroot"

	#check if nginx is installed
	if [[ $(ps -ef | grep nginx | grep -v $0 | grep -v grep) == "" && $(whereis nginx | awk -F ':' '{print $2}') == "" ]];then
		cd $curPath/nginx
		if [[ -f "$file_nginx_package" && -f "$file_nginx_conf" ]];then
			rm -rf $nginx_home
			rm -rf $nginx_root_dir
			mkdir -p $nginx_home
			mkdir -p $nginx_root_dir

			#add nginx user and group
			if ! grep "$nginx_group" /etc/group > /dev/null;then
				groupadd $nginx_group
			fi

			if ! grep "$nginx_user" /etc/passwd > /dev/null;then
				useradd -M -s /sbin/nologin -g $nginx_group $nginx_user
			fi

			#compile and install
			tar xvf $file_nginx_package
			cd nginx-1.12.2
			./configure --prefix=$nginx_home \
						--user=$nginx_user \
						--group=$nginx_group \
						--sbin-path=$nginx_home/bin/nginx \
						--conf-path=$nginx_home/conf/nginx.conf \
						--pid-path=$nginx_home/run/nginx.pid \
						--lock-path=$nginx_home/run/nginx.lock \
						--error-log-path=$nginx_home/log/error.log \
						--http-log-path=$nginx_home/log/access.log \
						--with-http_ssl_module \
						--with-http_realip_module \
						--with-http_addition_module \
						--with-http_sub_module \
						--with-http_gunzip_module \
						--with-http_gzip_static_module \
						--with-http_random_index_module \
						--with-http_secure_link_module \
						--with-http_auth_request_module 

			make && make install
	
			# nginx conf
			cp -f $curPath/nginx/nginx.conf /usr/local/nginx/conf/nginx.conf
			chmod 640 /usr/local/nginx/conf/nginx.conf
			cp -f $curPath/nginx/nginx_ctl /usr/local/nginx/bin/nginx_ctl
			chmod 750  /usr/local/nginx/bin/nginx_ctl

			chown -R $nginx_user:$nginx_group $nginx_home
			chown -R $nginx_user:$nginx_group $nginx_root_dir

			#start nginx
			sudo -u $nginx_user /usr/local/nginx/bin/nginx_ctl start
			return 0
		else
			echo "There is no nginx file, please check!!"
			return 1
		fi
	else
    	echo "nginx is installed，please check！！"
		return 1
	fi
}

function install_postgres()
{
	file_postgres_package="postgresql-10.1.tar.gz"
	file_postgres_password="pg_pwfile"
	pgsql_home="/usr/local/pgsql"
	pgsql_data=$pgsql_home/data
	pgsql_user="postgres"
	pgsql_group="postgres"

	#check if nginx is installed
	if [[ $(ps -ef | grep postgres | grep -v $0 | grep -v grep) == "" && $(whereis pgsql | awk -F ':' '{print $2}') == "" ]];then
		cd $curPath/pgsql
		if [[ -f "$file_postgres_package" && -f "$file_postgres_password" ]];then
			rm -rf $pgsql_home
			mkdir -p $pgsql_data

			tar xvf $file_postgres_package
			cd postgresql-10.1
			./configure
			make && make PREFIX=$pgsql_home install

			#add pgsql user and group
			if ! grep "$pgsql_group" /etc/group > /dev/null;then
				groupadd $pgsql_group
			fi

			if ! grep "$pgsql_user" /etc/passwd > /dev/null;then
				useradd -M -s /sbin/nologin -g $pgsql_group $pgsql_user
			fi
			chown -R $pgsql_user:$pgsql_group $pgsql_home

			#init pgsql
			sudo -u $pgsql_user /usr/local/pgsql/bin/initdb -D /usr/local/pgsql/data --encoding=UTF-8 --locale=zh_CN.UTF-8 --pwfile=$curPath/pgsql/pg_pwfile

			# pgsql config
			cp -f $curPath/pgsql/postgresql.conf $pgsql_data
			chmod 640 $pgsql_data/postgresql.conf
			chown $pgsql_user:$pgsql_group $pgsql_data/postgresql.conf
			cp -f $curPath/pgsql/pg_hba.conf $pgsql_data
			chmod 640 $pgsql_data/pg_hba.conf
			chown $pgsql_user:$pgsql_group $pgsql_data/pg_hba.conf
			
			#start pgsql
			sudo -u $pgsql_user /usr/local/pgsql/bin/pg_ctl start -D /usr/local/pgsql/data/ -l /usr/local/pgsql/data/logfile 
			return 0
		else
			echo "There is no pgsql file, please check!!"
			return 1
		fi
	else
    	echo "pgsql is installed，please check！！"
		return 1
	fi
}

function install_caddy()
{
	file_caddy_package="caddy_v0.10.11_linux_amd64_personal.tar.gz"
	file_caddy_conf="Caddyfile"
	file_caddy_supervise="supervise.caddy"
	file_caddy_ctl="caddy_ctl"
	caddy_home="/usr/local/caddy"
	caddy_user="caddy"
	caddy_group="caddy"

	#check if caddy is installed
	if [[ $(ps -ef | grep caddy | grep -v $0 | grep -v grep) == "" && $(whereis caddy | awk -F ':' '{print $2}') == "" ]];then
		cd $curPath/caddy
		if [[ -f "$file_caddy_package" && -f "$file_caddy_conf" ]];then
			rm -rf $caddy_home
			mkdir -p $caddy_home/bin
			mkdir -p $caddy_home/conf
			mkdir -p $caddy_home/status/caddy

			#add caddy file
			cp -f $file_caddy_conf $caddy_home/conf && chmod 640 $caddy_home/conf/$file_caddy_conf
			cp -f $file_caddy_ctl $caddy_home/bin && chmod 750 $caddy_home/bin/$file_caddy_ctl
			cp -f $file_caddy_supervise $caddy_home/bin && chmod 750 $caddy_home/bin/$file_caddy_supervise

			tar xvf $file_caddy_package
			cp -f caddy $caddy_home/bin && chmod 750 $caddy_home/bin/caddy

			#add caddy user and group
			if ! grep "$caddy_group" /etc/group > /dev/null;then
				groupadd $caddy_group
			fi
			if ! grep "$caddy_user" /etc/passwd > /dev/null;then
				useradd -M -s /sbin/nologin -g $caddy_group $caddy_user
			fi
			chown -R $caddy_user:$caddy_group $caddy_home

			#start caddy
			sudo -u $caddy_user $caddy_home/bin/caddy_ctl start
		else
			echo "There is no pgsql file, please check!!"
			return 1
		fi
	else
		echo "caddy is installed，please check！！"
		return 1
	fi
}

function install_mysql()
{
	file_mysql_package="mysql-5.7.21.tar.gz"
	file_boost_package="mysql-boost-5.7.21.tar.gz"
	mysql_home="/usr/local/mysql"
	mysql_user="mysql"
	mysql_group="mysql"

	#check if mysql is installed
	if [[ $(ps -ef | grep mysql | grep -v $0 | grep -v grep) == "" ]];then
		cd $curPath/mysql
		if [[ -f "$file_mysql_package" && -f "$file_boost_package" ]];then
			rm -rf $mysql_home
			rm -f /etc/my.conf
			mkdir -p $mysql_home/data
			mkdir -p $mysql_home/conf

			#如果linux运行内存小于2G，建议设置虚拟内存
			dd if=/dev/zero of=/swapfile bs=64M count=32
			mkswap /swapfile
			swapon /swapfile

			#compile and install
			tar xvf $file_mysql_package
			tar xvf $file_boost_package
			cd mysql-5.7.21
			cmake \
				-DCMAKE_INSTALL_PREFIX=/usr/local/mysql \
				-DMYSQL_DATADIR=/usr/local/mysql/data \
				-DSYSCONFDIR=/usr/local/mysql/conf \
				-DWITH_MYISAM_STORAGE_ENGINE=1 \
				-DWITH_INNOBASE_STORAGE_ENGINE=1 \
				-DMYSQL_UNIX_ADDR=/usr/local/mysql/mysql.sock \
				-DMYSQL_TCP_PORT=3306 \
				-DENABLED_LOCAL_INFILE=1 \
				-DENABLE_DOWNLOADS=1 \
				-DWITH_PARTITION_STORAGE_ENGINE=1 \
				-DEXTRA_CHARSETS=all \
				-DDEFAULT_CHARSET=utf8 \
				-DDEFAULT_COLLATION=utf8_general_ci \
				-DWITH_DEBUG=0 \
				-DMYSQL_MAINTAINER_MODE=0 \
				-DWITH_SSL:STRING=bundled \
				-DWITH_ZLIB:STRING=bundled \
				-DDOWNLOAD_BOOST=1 \
				-DWITH_BOOST=../boost
			make && make install

			#delete swap memory
			swapoff /swapfile
			rm -f /swapfile

			#add mysql conf
			cp -f $curPath/mysql/my.cnf $mysql_home/conf/
			chmod 640  $mysql_home/conf/my.cnf

			#add mysql user and group
			if ! grep "$mysql_group" /etc/group > /dev/null;then
				groupadd $mysql_group
			fi

			if ! grep "$mysql_user" /etc/passwd > /dev/null;then
				useradd -M -s /sbin/nologin -g $mysql_group $mysql_user
			fi
			chown -R $mysql_user:$mysql_group $mysql_home

			#init mysql
			sudo -u $mysql_user /usr/local/mysql/bin/mysqld --initialize-insecure --user=$mysql_user --basedir=/usr/local/mysql --datadir=/usr/local/mysql/data
			
			#add mysql to system service
			cp -f $mysql_home/support-files/mysql.server /etc/init.d/mysql  
			chkconfig --add mysql
			chkconfig mysql on

			#start mysql
			service mysql start

		else
			echo "There is no mysql file, please check!!"
			return 1
		fi
	else
		echo "mysql is installed，please check！！"
		return 1
	fi
}

if [ $# -lt 1 ];then
	Usage
	exit 0
fi

install_common

case $1 in
redis)
	install_redis
	if [ "$?" != 0 ];then
		echo "Install redis failed!"
	else
		echo "Install Redis Success"
	fi
	;;
nginx)
	install_nginx
	if [ "$?" != 0 ];then
		echo "Install nginx failed!"
	else
		echo "Install nginx Success"
	fi
	;;
postgres)
	install_postgres
	if [ "$?" != 0 ];then
		echo "Install postgres failed!"
	else
		echo "Install postgres Success"
	fi
	;;
caddy)
	install_caddy
	if [ "$?" != 0 ];then
		echo "Install caddy failed!"
	else
		echo "Install caddy Success"
	fi
	;;
mysql)
	install_mysql
	if [ "$?" != 0 ];then
		echo "Install mysql failed!"
	else
		echo "Install mysql Success"
	fi
	;;
all)
	;;
*)
	echo "Sorry, don't support $1 install!!"
	;;
esac
