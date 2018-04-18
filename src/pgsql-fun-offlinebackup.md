# Postgresql冷备份与恢复实战

> JackGao
>
> Email: jackgo73@outlook.com
>
> Date:  20180418

## 背景

数据库冷备份需要停机状态进行，备份后得到一个完整的数据库镜像。由于数据库停机所以不存在热数据，需要注意的主要是恢复环境、表空间等其他文件、XLOG等。

## 构造测试库

构造**随机测试数据**并模拟业务操作生成XLOG


```sql
testdb=# select pg_size_pretty(pg_database_size('testdb'));
 pg_size_pretty 
----------------
 7343 kB
(1 row)

...
create table t1(id int, info text, crt_time timestamp);
create table t2(id int, info text, crt_time timestamp);
create table t3(id int, info text, crt_time timestamp);
create table t4(id int, info text, crt_time timestamp);
create table t5(id int, info text, crt_time timestamp);
create table t6(id int, info text, crt_time timestamp);
create table t7(id int, info text, crt_time timestamp);
create table t8(id int, info text, crt_time timestamp);
insert into t1 select generate_series(1,1200000),md5(random()::text),clock_timestamp();
insert into t2 select generate_series(1,1150000),md5(random()::text),clock_timestamp();
insert into t3 select generate_series(1,1100000),md5(random()::text),clock_timestamp();
insert into t4 select generate_series(1,1300000),md5(random()::text),clock_timestamp();
insert into t5 select generate_series(1,1400000),md5(random()::text),clock_timestamp();
insert into t6 select generate_series(1,1100000),md5(random()::text),clock_timestamp();
insert into t7 select generate_series(1,1100000),md5(random()::text),clock_timestamp();
insert into t8 select generate_series(1,1500000),md5(random()::text),clock_timestamp();
...

testdb=# select pg_size_pretty(pg_database_size('testdb'));
 pg_size_pretty 
----------------
 795 MB
(1 row)

testdb=# create tablespace ts1 location '/home/jackgo/databases/data/pgdata8400_tablespace';
CREATE TABLESPACE


create table test03 (id int primary key, info text);

test.sql
\set id random(1,100)
insert into test03 values(:id, repeat(md5(random()::text), 1000)) on conflict on constraint test03_pkey do update set info=excluded.info;

pgbench -M prepared -n -r -P 1 -f ./test.sql -c 48 -j 48 -T 10000000
```

## 确定备份范围

确定DATA文件和XLOG文件位置（pg_xlog符号链接）

```
[jackgo@localhost ~/databases/data/pgdata8400][00]$ ll
total 88
drwx------. 5 jackgo jackgo    41 Apr 17 22:24 base
drwx------. 2 jackgo jackgo  4096 Apr 17 21:57 global
drwx------. 2 jackgo jackgo    18 Apr 15 20:51 pg_clog
drwx------. 2 jackgo jackgo     6 Apr 15 20:51 pg_commit_ts
drwx------. 2 jackgo jackgo     6 Apr 15 20:51 pg_dynshmem
-rw-------. 1 jackgo jackgo  4468 Apr 15 20:51 pg_hba.conf
-rw-------. 1 jackgo jackgo  1636 Apr 15 20:51 pg_ident.conf
drwx------. 2 jackgo jackgo   126 Apr 17 22:17 pg_log
drwx------. 4 jackgo jackgo    39 Apr 15 20:51 pg_logical
drwx------. 4 jackgo jackgo    36 Apr 15 20:51 pg_multixact
drwx------. 2 jackgo jackgo    18 Apr 15 20:52 pg_notify
drwx------. 2 jackgo jackgo     6 Apr 15 20:51 pg_replslot
drwx------. 2 jackgo jackgo     6 Apr 15 20:51 pg_serial
drwx------. 2 jackgo jackgo     6 Apr 17 04:46 pg_snapshots
drwx------. 2 jackgo jackgo     6 Apr 15 20:51 pg_stat
drwx------. 2 jackgo jackgo    63 Apr 17 22:40 pg_stat_tmp
drwx------. 2 jackgo jackgo    18 Apr 17 22:21 pg_subtrans
drwx------. 2 jackgo jackgo     6 Apr 15 20:51 pg_tblspc
drwx------. 2 jackgo jackgo     6 Apr 15 20:51 pg_twophase
-rw-------. 1 jackgo jackgo     4 Apr 15 20:51 PG_VERSION
lrwxrwxrwx. 1 jackgo jackgo    50 Apr 15 20:51 pg_xlog -> /home/jackgo/databases/data/pgdata8400/pg_xlog8400
drwx------. 3 jackgo jackgo  4096 Apr 17 22:39 pg_xlog8400
-rw-------. 1 jackgo jackgo    88 Apr 15 20:51 postgresql.auto.conf
-rw-------. 1 jackgo jackgo 21765 Apr 16 05:24 postgresql.conf
-rw-------. 1 jackgo jackgo 21765 Apr 15 20:51 postgresql.confr
-rw-------. 1 jackgo jackgo    46 Apr 15 20:52 postmaster.opts
-rw-------. 1 jackgo jackgo    93 Apr 15 20:52 postmaster.pid
```

确定表空间文件位置

```
[jackgo@localhost ~/databases/data/pgdata8400/pg_tblspc][00]$ ll
total 0
lrwxrwxrwx. 1 jackgo jackgo 49 Apr 17 22:44 16645 -> /home/jackgo/databases/data/pgdata8400_tablespace
```

其他文件目录

```
[jackgo@localhost ~/databases/data/pgdata8400][00]$ grep -E -i "dir|file" postgresql.conf
# PostgreSQL configuration file
# This file consists of lines of the form:
# The commented-out settings shown in this file represent the default values.
# This file is read on server startup and when the server receives a SIGHUP
# signal.  If you edit the file on a running system, you have to SIGHUP the
# FILE LOCATIONS
# option or PGDATA environment variable, represented here as ConfigDir.
#data_directory = 'ConfigDir'		# use data in another directory
#hba_file = 'ConfigDir/pg_hba.conf'	# host-based authentication file
#ident_file = 'ConfigDir/pg_ident.conf'	# ident configuration file
# If external_pid_file is not explicitly set, no extra PID file is written.
#external_pid_file = ''			# write an extra PID file
unix_socket_directories = '.'
#ssl_cert_file = 'server.crt'		# (change requires restart)
#ssl_key_file = 'server.key'		# (change requires restart)
#ssl_ca_file = ''			# (change requires restart)
#ssl_crl_file = ''			# (change requires restart)
#krb_server_keyfile = ''
#temp_file_limit = -1			# limits per-process temp file space
#max_files_per_process = 1000		# min 25
#vacuum_cost_page_dirty = 20		# 0-10000 credits
#archive_command = ''		# command to use to archive a logfile segment
				# placeholders: %p = path of file to archive
				#               %f = file name only
				# e.g. 'test ! -f /mnt/server/archivedir/%f && cp %p /mnt/server/archivedir/%f'
#archive_timeout = 0		# force a logfile segment switch after this
#wal_keep_segments = 0		# in logfile segments, 16MB each; 0 disables
					# into log files. Required to be on for
log_directory = 'pg_log'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
#log_file_mode = 0600			# creation mode for log files,
					# same name as the new log file will be
					# off, meaning append to existing files
#log_temp_files = -1			# log temporary files equal or larger
					# -1 disables, 0 logs all temp files
#stats_temp_directory = 'pg_stat_tmp'
					# You can create your own file in
#dynamic_library_path = '$libdir'
# CONFIG FILE INCLUDES
# These options allow settings to be loaded from files other than the
#include_dir = 'conf.d'			# include files ending in '.conf' from
					# directory 'conf.d'
#include_if_exists = 'exists.conf'	# include file only if it exists
#include = 'special.conf'		# include file
```

- 使用pg_config看一下安装的环境有没有依赖其他非常见的库，如果有注意新环境的pg要保持一致
- ```cat postgresql.conf | grep shared_preload_libraries```确定下有没有装三方插件

## 备份

注意：如果pg_xlog和pg_tblspc有软连接，这里需要额外记录一下位置。rsync加参数把软连接指向的文件直接备份，源文件路径信息丢失。

```shell
[jackgo@localhost ~/databases/data][00]$ pg_ctl stop -m fast
waiting for server to shut down.... done
server stopped

# rsync会把符号链接的指向的文件都拷过来，所以不需要单独备份符号链接相关的文件了
# 注意恢复的时候需要手动恢复成符号链接
[jackgo@localhost ~/databases/data][00]$ rsync -acvz -L --exclude "pg_xlog8400" --exclude "pg_xlog" --exclude "pg_log" $PGDATA ./pgdata8400bak    
sending incremental file list
created directory ./pgdata8400bak
pgdata8400/
...
...

# 单独备份有效xlog
[jackgo@localhost ~/databases/data][00]$ pg_controldata | grep checkpoint    
Latest checkpoint location:           3/2D25EA20
Prior checkpoint location:            3/2D25E9B0
Latest checkpoint's REDO location:    3/2D25EA20
Latest checkpoint's REDO WAL file:    00000001000000030000002D
Latest checkpoint's TimeLineID:       1
Latest checkpoint's PrevTimeLineID:   1
Latest checkpoint's full_page_writes: on
Latest checkpoint's NextXID:          0:86491
Latest checkpoint's NextOID:          16646
Latest checkpoint's NextMultiXactId:  1
Latest checkpoint's NextMultiOffset:  0
Latest checkpoint's oldestXID:        1750
Latest checkpoint's oldestXID's DB:   1
Latest checkpoint's oldestActiveXID:  0
Latest checkpoint's oldestMultiXid:   1
Latest checkpoint's oldestMulti's DB: 1
Latest checkpoint's oldestCommitTsXid:0
Latest checkpoint's newestCommitTsXid:0
Time of latest checkpoint:            Wed 18 Apr 2018 02:12:13 AM EDT

[jackgo@localhost ~/databases/data][00]$ ll -rt pgdata8400/pg_xlog8400/00000001000000030000002*
-rw-------. 1 jackgo jackgo 16777216 Apr 17 21:58 pgdata8400/pg_xlog8400/00000001000000030000002E
-rw-------. 1 jackgo jackgo 16777216 Apr 17 21:58 pgdata8400/pg_xlog8400/00000001000000030000002F
-rw-------. 1 jackgo jackgo 16777216 Apr 18 02:12 pgdata8400/pg_xlog8400/00000001000000030000002D

# 创建xlog文件夹 拷贝 需要的xlog
[jackgo@localhost ~/databases/data][00]$ mkdir pgdata8400bak/pgdata8400/pg_xlog
[jackgo@localhost ~/databases/data][00]$ chmod 700 pgdata8400bak/pgdata8400/pg_xlog

[jackgo@localhost ~/databases/data][00]$ cp pgdata8400/pg_xlog/00000001000000030000002D pgdata8400bak/pgdata8400/pg_xlog/



```

## 恢复

- 确定目标环境与原环境软件一致
- 关注 CONFIGURE、VERSION、LIBS，依赖库是否都全

```
[jackgo@localhost ~/databases/data][00]$ pg_config 
BINDIR = /home/jackgo/databases/pgsql8400/bin
DOCDIR = /home/jackgo/databases/pgsql8400/share/doc
HTMLDIR = /home/jackgo/databases/pgsql8400/share/doc
INCLUDEDIR = /home/jackgo/databases/pgsql8400/include
PKGINCLUDEDIR = /home/jackgo/databases/pgsql8400/include
INCLUDEDIR-SERVER = /home/jackgo/databases/pgsql8400/include/server
LIBDIR = /home/jackgo/databases/pgsql8400/lib
PKGLIBDIR = /home/jackgo/databases/pgsql8400/lib
LOCALEDIR = /home/jackgo/databases/pgsql8400/share/locale
MANDIR = /home/jackgo/databases/pgsql8400/share/man
SHAREDIR = /home/jackgo/databases/pgsql8400/share
SYSCONFDIR = /home/jackgo/databases/pgsql8400/etc
PGXS = /home/jackgo/databases/pgsql8400/lib/pgxs/src/makefiles/pgxs.mk
CONFIGURE = '--prefix=/home/jackgo/databases/pgsql8400' '--with-openssl' '--enable-debug' '--enable-cassert' '--enable-thread-safety' 'CFLAGS=-ggdb -Og -g3 -fno-omit-frame-pointer' '--with-pgport=8400' '--enable-depend'
CC = gcc
CPPFLAGS = -DFRONTEND -D_GNU_SOURCE
CFLAGS = -Wall -Wmissing-prototypes -Wpointer-arith -Wdeclaration-after-statement -Wendif-labels -Wmissing-format-attribute -Wformat-security -fno-strict-aliasing -fwrapv -fexcess-precision=standard -g -ggdb -Og -g3 -fno-omit-frame-pointer
CFLAGS_SL = -fPIC
LDFLAGS = -L../../src/common -Wl,--as-needed -Wl,-rpath,'/home/jackgo/databases/pgsql8400/lib',--enable-new-dtags
LDFLAGS_EX = 
LDFLAGS_SL = 
LIBS = -lpgcommon -lpgport -lssl -lcrypto -lz -lreadline -lrt -lcrypt -ldl -lm  
VERSION = PostgreSQL 9.6.8
```



1 恢复DATA目录

```
[jackgo@localhost ~/databases/data][00]$ mkdir pgdata8400
[jackgo@localhost ~/databases/data][00]$ chmod 700 pgdata8400
[jackgo@localhost ~/databases/data][00]$ cp -r pgdata8400bak/pgdata8400/* pgdata8400/
```

2 创建pg_log

```
[jackgo@localhost ~/databases/data][00]$ mkdir pgdata8400/pg_log
[jackgo@localhost ~/databases/data][00]$ chmod 700 pgdata8400/pg_log
```

3 恢复软连接

```
[jackgo@localhost ~/databases/data][00]$ mv pgdata8400/pg_xlog/ pgdata8400/pg_xlog8400
[jackgo@localhost ~/databases/data][00]$ ln -s /home/jackgo/databases/data/pgdata8400/pg_xlog8400 /home/jackgo/databases/data/pgdata8400/pg_xlog

[jackgo@localhost ~/databases/data][00]$ mkdir pgdata8400_tablespace
[jackgo@localhost ~/databases/data][00]$ mv pgdata8400/pg_tblspc/16645/* pgdata8400_tablespace/
[jackgo@localhost ~/databases/data][00]$ rm -rf pgdata8400/pg_tblspc/16645/
[jackgo@localhost ~/databases/data][00]$ ln -s /home/jackgo/databases/data/pgdata8400_tablespace /home/jackgo/databases/data/pgdata8400/pg_tblspc/16645
```

4 启动数据库

```
[jackgo@localhost ~/databases/data][00]$ pg_ctl start
server starting
1898    2018-04-18 07:02:38 UTC 00000LOG:  redirecting log output to logging collector process
1898    2018-04-18 07:02:38 UTC 00000HINT:  Future log output will appear in directory "pg_log".

[jackgo@localhost ~/databases/data/pgdata8400/pg_log][00]$ cat postgresql-2018-04-18_070238.log 
1900    2018-04-18 07:02:38 UTC 00000LOG:  database system was shut down at 2018-04-18 06:12:13 UTC
1900    2018-04-18 07:02:38 UTC 00000LOG:  creating missing WAL directory "pg_xlog/archive_status"
1900    2018-04-18 07:02:38 UTC 00000LOG:  MultiXact member wraparound protections are now enabled
1898    2018-04-18 07:02:38 UTC 00000LOG:  database system is ready to accept connections
1907    2018-04-18 07:02:38 UTC 00000LOG:  autovacuum launcher started
```

5 验证

```
[jackgo@localhost ~/databases/data][00]$ psql testdb
psql (9.6.8)
Type "help" for help.

testdb=# \d
              List of relations
 Schema |       Name       | Type  |  Owner   
--------+------------------+-------+----------
 public | pgbench_accounts | table | postgres
 public | pgbench_branches | table | postgres
 public | pgbench_history  | table | postgres
 public | pgbench_tellers  | table | postgres
 public | t1               | table | postgres
 public | t2               | table | postgres
 public | t3               | table | postgres
 public | t4               | table | postgres
 public | t5               | table | postgres
 public | t6               | table | postgres
 public | t7               | table | postgres
 public | t8               | table | postgres
 public | test03           | table | postgres
(13 rows)

```

## 参考

https://github.com/digoal/blog/blob/master/201608/20160823_02.md