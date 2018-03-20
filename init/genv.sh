
if [ $# != 1 ] ; then 
echo "USAGE: $0 db_number" 
echo "       $0 alias"
exit 1; 
fi 

if [ $1 == "alias" ] ; then
echo "alias pp=\"source `pwd`/$0\"" >> $HOME/.bashrc 
cat $HOME/.bashrc
exit 1;
fi

# ----------Prefix   ----------

PG_PORT_PRE=84
PG_DIR_PRE=$HOME/databases

MY_PORT_PRE=73
MY_DIR_PRE=$HOME/databases

# ---------Postgresql---------

export PS1="[\u@\h \w][$1]\\$ "
export PGPORT=$PG_PORT_PRE$1
export PGDATA=$PG_DIR_PRE/data/pgdata$PGPORT
export LANG=en_US.utf8
export PGHOME=$PG_DIR_PRE/pgsql$PGPORT
export LD_LIBRARY_PATH=$PGHOME/lib:/lib64:/usr/lib64:/usr/local/lib64:/lib:/usr/lib:/usr/local/lib:$LD_LIBRARY_PATH
export DATE=`date +"%Y%m%d%H%M"`
export PATH=$PGHOME/bin:$PATH:.
export MANPATH=$PGHOME/share/man:$MANPATH
export PGHOST=$PGDATA
export PGUSER=postgres
export PGDATABASE=postgres

# -----------Mysql------------

export MYSQLPORT=$MY_PORT_PRE$1
export MYSQLHOME=$MY_DIR_PRE/mysql$MYSQLPORT
export MYSQLDATA=$MY_DIR_PRE/data/mydata$MYSQLPORT

export PATH=$PGHOME/bin:$MYSQLHOME/bin:$PATH:.

alias rm='rm -i'
alias ll='ls -lh'

\cp $MYSQLDATA/my.cnf $HOME/.my.cnf

function help_pg()
{
cat << EOF
==========================================================================
wget -S https://ftp.postgresql.org/pub/source/v9.6.8/postgresql-9.6.8.tar.gz
wget -S https://ftp.postgresql.org/pub/source/v10.3/postgresql-10.3.tar.gz
==========================================================================
yum -y install coreutils glib2 lrzsz sysstat e4fsprogs xfsprogs ntp readline-devel zlib zlib-devel openssl openssl-devel pam-devel libxml2-devel libxslt-devel python-devel tcl-devel gcc make smartmontools flex bison perl perl-devel perl-ExtUtils* openldap openldap-devel
==========================================================================
./configure --prefix=$PG_DIR_PRE/pgsql8400 --with-openssl --enable-debug --enable-cassert --enable-thread-safety CFLAGS='-O0' --with-pgport=8400 --enable-depend;
./configure --prefix=$PG_DIR_PRE/pgsql8400 --with-openssl --enable-debug --enable-cassert --enable-thread-safety CFLAGS='-ggdb -Og -g3 -fno-omit-frame-pointer' --with-pgport=8400 --enable-depend;
make -sj12;
make install;
==========================================================================
initdb -D $PGDATA -E UTF8 --locale=C -U postgres -X $PGDATA/pg_xlog$PGPORT
==========================================================================
sed -ir "s/#*unix_socket_directories.*/unix_socket_directories = '.'/" $PGDATA/postgresql.conf
sed -ir "s/#*unix_socket_permissions.*/unix_socket_permissions = 0700/" $PGDATA/postgresql.conf
sed -ir "s/#*max_connections.*/max_connections = 800/" $PGDATA/postgresql.conf
sed -ir "s/#*superuser_reserved_connections.*/superuser_reserved_connections = 13/" $PGDATA/postgresql.conf
sed -ir "s/#*logging_collector.*/logging_collector= on/" $PGDATA/postgresql.conf
sed -ir "s/#*log_directory.*/log_directory = 'pg_log'/" $PGDATA/postgresql.conf
sed -ir "s/#*log_filename.*/log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'/" $PGDATA/postgresql.conf
sed -ir "s/#*log_rotation_size.*/log_rotation_size = 10MB/" $PGDATA/postgresql.conf
sed -ir "s/#*log_line_prefix.*/log_line_prefix='%p %r %u %d %t %e'/" $PGDATA/postgresql.conf
sed -ir "s/#*log_min_duration_statement.*/log_min_duration_statement= 1000/" $PGDATA/postgresql.conf
sed -ir "s/#*log_timezone.*/log_timezone = 'UTC'/" $PGDATA/postgresql.conf
sed -ir "s/#*log_truncate_on_rotation.*/log_truncate_on_rotation = on/" $PGDATA/postgresql.conf
sed -ir "s/#*log_rotation_age.*/log_rotation_age = 0/" $PGDATA/postgresql.conf
sed -ir "s/#*log_statement.*/log_statement= 'all'/" $PGDATA/postgresql.conf
sed -ir "s/#*max_prepared_transactions.*/max_prepared_transactions= 800/" $PGDATA/postgresql.conf
==========================================================================
EOF
}

function help_mysql()
{
cat << EOF
==========================================================================
yum -y install gcc-c++ ncurses-devel cmake make perl gcc autoconf automake zlib libxml libgcrypt libtool bison
==========================================================================
wget http://nchc.dl.sourceforge.net/project/boost/boost/1.59.0/boost_1_59_0.tar.gz
tar zxvf  boost_1_59_0.tar.gz
mv boost_1_59_0 /usr/local/boost
==========================================================================
wget https://dev.mysql.com/get/Downloads/MySQL-5.7/mysql-5.7.20.tar.gz
mkdir ~/Projects/mysql-5.7.20;tar xzvf mysql-5.7.20.tar.gz -C ~/Projects/
cmake -DCMAKE_INSTALL_PREFIX=$MY_DIR_PRE/mysql7300 \
-DMYSQL_DATADIR=$MY_DIR_PRE/data/mydata7300 \
-DDEFAULT_CHARSET=utf8 \
-DDEFAULT_COLLATION=utf8_general_ci \
-DMYSQL_TCP_PORT=7300 \
-DMYSQL_USER=jackgo \
-DWITH_MYISAM_STORAGE_ENGINE=1 \
-DWITH_INNOBASE_STORAGE_ENGINE=1 \
-DWITH_ARCHIVE_STORAGE_ENGINE=1 \
-DWITH_BLACKHOLE_STORAGE_ENGINE=1 \
-DWITH_MEMORY_STORAGE_ENGINE=1 \
-DDOWNLOAD_BOOST=1 \
-DWITH_BOOST=/usr/local/boost
make -sj8;
make install;
==========================================================================
mysqld --initialize --user=mysql --basedir=$MYSQLHOME  --datadir=$MYSQLDATA
#  temporary password is generate
mv /etc/my.cnf /etc/my.cnf.bak
mysqld --verbose --help |grep -A 1 'Default options'
mysqld_safe&
mysql --socket=$MYSQLDATA/mysql.sock -p7300 -uroot -p'u?>W0-49GB8Q'
alter user 'root'@'localhost' identified by '123456';
mysqladmin shutdown -S $MYSQLDATA/mysql.sock -p'333' -uroot
==========================================================================

EOF
}

function help_me()
{
cat << EOF
==========================================================================
GIT Config
git config --global user.email "jackgo73@outlook.com"
git config --global user.name "Jack Go"
==========================================================================
SSH
ssh-keygen -t rsa -b 4096 -C "jackgo73@outlook.com"
==========================================================================
GIT Shadowsockets
git config --global http.proxy 'socks5://127.0.0.1:1091' 
git config --global https.proxy 'socks5://127.0.0.1:1091'
==========================================================================
SAMBA
yum install samba samba-client 
vim /etc/samba/smb.conf
[homes]
  comment = Home Directories
  browseable = Yes
  read only = No
  valid users = jackgo

smbpasswd -a jackgo
firewall-cmd --permanent --zone=public --add-service=samba
firewall-cmd --reload
setsebool -P samba_enable_home_dirs on
setsebool -P samba_export_all_rw on
#vi /etc/selinux/config
#SELINUX=disabled
# no need to "setenforce 0"
# no need to "systemctl stop firewalld.service"
# no need to "systemctl disable  firewalld.service     #开启不启动"
systemctl enable smb nmb
systemctl restart smb nmb
==========================================================================
CORE
echo core.%e.%p.SIG%s.%t > /proc/sys/kernel/core_pattern
echo 63 > /proc/self/coredump_filter # include shared memory
ulimit -c unlimited
==========================================================================
GDB
handle SIGUSR1 noprint pass
debug short-live proc:
```
   /* You may need to #include "miscadmin.h" and <unistd.h> */
   
   bool continue_sleep = true;
   do {
       sleep(1);
       elog(LOG, "zzzzz %d", MyProcPid);
   } while (continue_sleep);
   
   func_to_debug()
```
==========================================================================

==========================================================================
EOF
}

