# Postgresql Tuning

> 参考德哥博文动手实践记录    jackgo73@outlook.com  20180710
>
> https://github.com/digoal/blog/blob/master/201203/20120313_01.md
>
> https://github.com/digoal/blog/blob/master/201203/20120313_02.md



## 构造表

```sql
create database tuning;
\c tuning

create table user_info  
(userid int,  
engname text,  
cnname text,  
occupation text,  
birthday date,  
signname text,  
email text,  
qq numeric,  
crt_time timestamp without time zone,  
mod_time timestamp without time zone  
);  
  
create table user_session  
(userid int,  
logintime timestamp(0) without time zone,  
login_count bigint default 0,  
logouttime timestamp(0) without time zone,  
online_interval interval default interval '0'  
);  
  
create table user_login_rec  
(userid int,  
login_time timestamp without time zone,  
ip inet  
);  
  
create table user_logout_rec  
(userid int,  
logout_time timestamp without time zone,  
ip inet  
);  

---

insert into user_info (userid,engname,cnname,occupation,birthday,signname,email,qq,crt_time,mod_time)  
select generate_series(1,20000000),  
'digoal.zhou',  
'德哥',  
'DBA',  
'1970-01-01'  
,E'公益是一辈子的事, I\'m Digoal.Zhou, Just do it!',  
'digoal@126.com',  
276732431,  
clock_timestamp(),  
NULL;  
  
insert into user_session (userid) select generate_series(1,20000000);  
  
set work_mem='2048MB';  
set maintenance_work_mem='2048MB';  
alter table user_info add constraint pk_user_info primary key (userid);  
alter table user_session add constraint pk_user_session primary key (userid);  

---

create or replace function f_user_login   
(i_userid int,  
OUT o_userid int,  
OUT o_engname text,  
OUT o_cnname text,  
OUT o_occupation text,  
OUT o_birthday date,  
OUT o_signname text,  
OUT o_email text,  
OUT o_qq numeric  
)  
as $BODY$  
declare  
begin  
select userid,engname,cnname,occupation,birthday,signname,email,qq  
into o_userid,o_engname,o_cnname,o_occupation,o_birthday,o_signname,o_email,o_qq  
from user_info where userid=i_userid;  
insert into user_login_rec (userid,login_time,ip) values (i_userid,now(),inet_client_addr());  
update user_session set logintime=now(),login_count=login_count+1 where userid=i_userid;  
return;  
end;  
$BODY$  
language plpgsql;  

create or replace function f_user_logout  
(i_userid int,  
OUT o_result int  
)  
as $BODY$  
declare  
begin  
insert into user_logout_rec (userid,logout_time,ip) values (i_userid,now(),inet_client_addr());  
update user_session set logouttime=now(),online_interval=online_interval+(now()-logintime) where userid=i_userid;  
o_result := 0;  
return;  
exception   
when others then  
o_result := 1;  
return;  
end;  
$BODY$  
language plpgsql;  
```

## 安装插件pg_stat_statements

略

## 参数配置

```shell
sed -ir "s/#*listen_addresses.*/listen_addresses = '0.0.0.0'/" $PGDATA/postgresql.conf
sed -ir "s/#*max_connections.*/max_connections = 1000/" $PGDATA/postgresql.conf
sed -ir "s/#*superuser_reserved_connections.*/superuser_reserved_connections = 3/" $PGDATA/postgresql.conf
sed -ir "s/#*unix_socket_directory.*/unix_socket_directory = '.'/" $PGDATA/postgresql.conf
sed -ir "s/#*unix_socket_permissions.*/unix_socket_permissions = 0700/" $PGDATA/postgresql.conf
sed -ir "s/#*tcp_keepalives_idle.*/tcp_keepalives_idle = 60/" $PGDATA/postgresql.conf
sed -ir "s/#*tcp_keepalives_interval.*/tcp_keepalives_interval = 10/" $PGDATA/postgresql.conf
sed -ir "s/#*tcp_keepalives_count.*/tcp_keepalives_count = 6/" $PGDATA/postgresql.conf
sed -ir "s/#*shared_buffers.*/shared_buffers = 512MB/" $PGDATA/postgresql.conf
sed -ir "s/#*maintenance_work_mem.*/maintenance_work_mem = 512MB/" $PGDATA/postgresql.conf
sed -ir "s/#*vacuum_cost_delay.*/vacuum_cost_delay = 10ms/" $PGDATA/postgresql.conf
sed -ir "s/#*bgwriter_delay.*/bgwriter_delay = 10ms/" $PGDATA/postgresql.conf
sed -ir "s/#*wal_level.*/wal_level = hot_standby/" $PGDATA/postgresql.conf
sed -ir "s/#*wal_buffers.*/wal_buffers = 32MB/" $PGDATA/postgresql.conf
sed -ir "s/#*checkpoint_timeout.*/checkpoint_timeout = 5min/" $PGDATA/postgresql.conf
sed -ir "s/#*archive_mode.*/archive_mode = on/" $PGDATA/postgresql.conf
sed -ir "s/#*archive_command.*/archive_command = '\/bin\/date'/" $PGDATA/postgresql.conf
sed -ir "s/#*max_wal_senders.*/max_wal_senders = 32/" $PGDATA/postgresql.conf
sed -ir "s/#*random_page_cost.*/random_page_cost = 2.0/" $PGDATA/postgresql.conf
sed -ir "s/#*effective_cache_size.*/effective_cache_size = 12000MB/" $PGDATA/postgresql.conf
sed -ir "s/#*log_destination.*/log_destination = 'csvlog'/" $PGDATA/postgresql.conf
sed -ir "s/#*logging_collector.*/logging_collector = on/" $PGDATA/postgresql.conf
sed -ir "s/#*log_directory.*/log_directory = 'pg_log'/" $PGDATA/postgresql.conf
sed -ir "s/#*log_truncate_on_rotation.*/log_truncate_on_rotation = on/" $PGDATA/postgresql.conf
sed -ir "s/#*log_rotation_age.*/log_rotation_age = 1d/" $PGDATA/postgresql.conf
sed -ir "s/#*log_rotation_size.*/log_rotation_size = 10MB/" $PGDATA/postgresql.conf
sed -ir "s/#*log_min_duration_statement.*/log_min_duration_statement = 1000ms/" $PGDATA/postgresql.conf
sed -ir "s/#*log_checkpoints.*/log_checkpoints = on/" $PGDATA/postgresql.conf
sed -ir "s/#*log_lock_waits.*/log_lock_waits = on/" $PGDATA/postgresql.conf
sed -ir "s/#*deadlock_timeout.*/deadlock_timeout = 1s/" $PGDATA/postgresql.conf
sed -ir "s/#*log_statement.*/log_statement = 'ddl'/" $PGDATA/postgresql.conf
sed -ir "s/#*track_activity_query_size.*/track_activity_query_size = 2048/" $PGDATA/postgresql.conf
sed -ir "s/#*autovacuum.*/autovacuum = on/" $PGDATA/postgresql.conf
sed -ir "s/#*log_autovacuum_min_duration.*/log_autovacuum_min_duration = 0/" $PGDATA/postgresql.conf
sed -ir "s/#*shared_preload_libraries.*/shared_preload_libraries = 'pg_stat_statements'/" $PGDATA/postgresql.conf
sed -ir "s/#*custom_variable_classes.*/custom_variable_classes = 'pg_stat_statements'/" $PGDATA/postgresql.conf

echo "pg_stat_statements.max = 1000" >> $PGDATA/postgresql.conf
echo "pg_stat_statements.track = all" >> $PGDATA/postgresql.conf
```

## (基线压测)pgbench

```
cat login.sql
\set userid random(1, 20000000)
select userid,engname,cnname,occupation,birthday,signname,email,qq from user_info where userid=:userid;  
insert into user_login_rec (userid,login_time,ip) values (:userid,now(),inet_client_addr());  
update user_session set logintime=now(),login_count=login_count+1 where userid=:userid;

cat logout.sql 
\set userid random(1, 20000000)
insert into user_logout_rec (userid,logout_time,ip) values (:userid,now(),inet_client_addr());  
update user_session set logouttime=now(),online_interval=online_interval+(now()-logintime) where userid=:userid;
```



老笔记本性能堪忧~

```
[jackgo@localhost ~/pgbench][00]$ pgbench -M simple -r -c 8 -f ./login.sql -j 8 -n -T 180 -h 127.0.0.1 -p 8400 tuning
transaction type: ./login.sql
scaling factor: 1
query mode: simple
number of clients: 8
number of threads: 8
duration: 180 s
number of transactions actually processed: 469481
latency average = 3.067 ms
tps = 2607.996300 (including connections establishing)
tps = 2608.079221 (excluding connections establishing)
script statistics:
 - statement latencies in milliseconds:
         0.002  \set userid random(1, 20000000)
         0.633  select userid,engname,cnname,occupation,birthday,signname,email,qq from user_info where userid=:userid;
         1.101  insert into user_login_rec (userid,login_time,ip) values (:userid,now(),inet_client_addr());
         1.334  update user_session set logintime=now(),login_count=login_count+1 where userid=:userid;
```

- tps = 2607.996300 (including connections establishing)
- tps = 2608.079221 (excluding connections establishing)



## (优化-->压测)PgFincore

安装

```
git clone git://git.postgresql.org/git/pgfincore.git
make clean
make
make install
psql tuning -f pgfincore--1.2.sql
```

```
mydb=# CREATE EXTENSION pgfincore;
```
使用
```sql
tuning=# select reltoastrelid from pg_class where relname='user_info';  
 reltoastrelid 
---------------
         32772
(1 row)

tuning=# select relname from pg_class where oid=32772;
    relname     
----------------
 pg_toast_32769
(1 row)

tuning=# select * from pgfadvise_willneed('pg_toast.pg_toast_32769');
     relpath      | os_page_size | rel_os_pages | os_pages_free 
------------------+--------------+--------------+---------------
 base/32768/32772 |         4096 |            0 |        242543
(1 row)

tuning=# select * from pgfadvise_willneed('user_info');
      relpath       | os_page_size | rel_os_pages | os_pages_free 
--------------------+--------------+--------------+---------------
 base/32768/32769   |         4096 |       262144 |        242489
 base/32768/32769.1 |         4096 |       262144 |        241987
 base/32768/32769.2 |         4096 |       244944 |        241987
(3 rows)

tuning=# select * from pgfadvise_willneed('user_session');
      relpath       | os_page_size | rel_os_pages | os_pages_free 
--------------------+--------------+--------------+---------------
 base/32768/32775   |         4096 |       262144 |        328600
 base/32768/32775.1 |         4096 |        36598 |        328600
(2 rows)

tuning=# select reltoastrelid from pg_class where relname='user_session';
 reltoastrelid 
---------------
             0
(1 row)

tuning=# select * from pgfadvise_willneed('pk_user_session');
     relpath      | os_page_size | rel_os_pages | os_pages_free 
------------------+--------------+--------------+---------------
 base/32768/32794 |         4096 |       109680 |        328569
(1 row)

tuning=# select * from pgfadvise_willneed('pk_user_info');
     relpath      | os_page_size | rel_os_pages | os_pages_free 
------------------+--------------+--------------+---------------
 base/32768/32792 |         4096 |       109680 |        328569
(1 row)
```

压测

```
[jackgo@localhost ~/pgbench][00]$ pgbench -M simple -r -c 8 -f ./login.sql -j 8 -n -T 180 -h 127.0.0.1 -p 8400 tuning
transaction type: ./login.sql
scaling factor: 1
query mode: simple
number of clients: 8
number of threads: 8
duration: 180 s
number of transactions actually processed: 480423
latency average = 2.998 ms
tps = 2668.774825 (including connections establishing)
tps = 2668.875187 (excluding connections establishing)
script statistics:
 - statement latencies in milliseconds:
         0.002  \set userid random(1, 20000000)
         0.631  select userid,engname,cnname,occupation,birthday,signname,email,qq from user_info where userid=:userid;
         1.069  insert into user_login_rec (userid,login_time,ip) values (:userid,now(),inet_client_addr());
         1.296  update user_session set logintime=now(),login_count=login_count+1 where userid=:userid
```

- tps = 2668.774825 (including connections establishing)
- tps = 2668.875187 (excluding connections establishing)

## (优化-->压测)异步提交

```sh
sed -ir "s/#*synchronous_commit.*/synchronous_commit = off/" $PGDATA/postgresql.conf
sed -ir "s/#*wal_writer_delay.*/wal_writer_delay = 10ms/" $PGDATA/postgresql.conf
```



```
[jackgo@localhost ~/pgbench][00]$ pgbench -M simple -r -c 8 -f ./login.sql -j 8 -n -T 180 -h 127.0.0.1 -p 8400 tuning
transaction type: ./login.sql
scaling factor: 1
query mode: simple
number of clients: 8
number of threads: 8
duration: 180 s
number of transactions actually processed: 586513
latency average = 2.455 ms
tps = 3258.348736 (including connections establishing)
tps = 3258.486241 (excluding connections establishing)
script statistics:
 - statement latencies in milliseconds:
         0.002  \set userid random(1, 20000000)
         0.853  select userid,engname,cnname,occupation,birthday,signname,email,qq from user_info where userid=:userid;
         0.709  insert into user_login_rec (userid,login_time,ip) values (:userid,now(),inet_client_addr());
         0.899  update user_session set logintime=now(),login_count=login_count+1 where userid=:userid;
```

- tps = 3258.348736 (including connections establishing)
- tps = 3258.486241 (excluding connections establishing)

## (优化-->压测)prepared协议

```
[jackgo@localhost ~/pgbench][00]$ pgbench -M prepared -r -c 8 -f ./login.sql -j 8 -n -T 180 -h 127.0.0.1 -p 8400 tuning
transaction type: ./login.sql
scaling factor: 1
query mode: prepared
number of clients: 8
number of threads: 8
duration: 180 s
number of transactions actually processed: 767341
latency average = 1.877 ms
tps = 4262.737631 (including connections establishing)
tps = 4263.028877 (excluding connections establishing)
script statistics:
 - statement latencies in milliseconds:
         0.002  \set userid random(1, 20000000)
         0.622  select userid,engname,cnname,occupation,birthday,signname,email,qq from user_info where userid=:userid;
         0.560  insert into user_login_rec (userid,login_time,ip) values (:userid,now(),inet_client_addr());
         0.693  update user_session set logintime=now(),login_count=login_count+1 where userid=:userid;
```





















---

## 拆表、提高并发数

暂时贴上测试方法，当前测试环境性能太差，CPU瓶颈导致并发上去性能急剧下降。

```sql
create table user_info_0 (like user_info including all);  
create table user_info_1 (like user_info including all);  
create table user_info_2 (like user_info including all);  
create table user_info_3 (like user_info including all);  
create table user_info_4 (like user_info including all);  
  
create table user_session_0 (like user_session including all);  
create table user_session_1 (like user_session including all);  
create table user_session_2 (like user_session including all);  
create table user_session_3 (like user_session including all);  
create table user_session_4 (like user_session including all);  

insert into user_info_0 (userid,engname,cnname,occupation,birthday,signname,email,qq,crt_time,mod_time)  
select generate_series(1,4000000),  
'digoal.zhou',  
'德哥',  
'DBA',  
'1970-01-01'  
,E'公益是一辈子的事, I\'m Digoal.Zhou, Just do it!',  
'digoal@126.com',  
276732431,  
clock_timestamp(),  
NULL;  
  
insert into user_info_1 (userid,engname,cnname,occupation,birthday,signname,email,qq,crt_time,mod_time)  
select generate_series(4000001,8000000),  
'digoal.zhou',  
'德哥',  
'DBA',  
'1970-01-01'  
,E'公益是一辈子的事, I\'m Digoal.Zhou, Just do it!',  
'digoal@126.com',  
276732431,  
clock_timestamp(),  
NULL;  
  
insert into user_info_2 (userid,engname,cnname,occupation,birthday,signname,email,qq,crt_time,mod_time)  
select generate_series(8000001,12000000),  
'digoal.zhou',  
'德哥',  
'DBA',  
'1970-01-01'  
,E'公益是一辈子的事, I\'m Digoal.Zhou, Just do it!',  
'digoal@126.com',  
276732431,  
clock_timestamp(),  
NULL;  
  
insert into user_info_3 (userid,engname,cnname,occupation,birthday,signname,email,qq,crt_time,mod_time)  
select generate_series(12000001,16000000),  
'digoal.zhou',  
'德哥',  
'DBA',  
'1970-01-01'  
,E'公益是一辈子的事, I\'m Digoal.Zhou, Just do it!',  
'digoal@126.com',  
276732431,  
clock_timestamp(),  
NULL;  
  
insert into user_info_4 (userid,engname,cnname,occupation,birthday,signname,email,qq,crt_time,mod_time)  
select generate_series(16000001,20000000),  
'digoal.zhou',  
'德哥',  
'DBA',  
'1970-01-01'  
,E'公益是一辈子的事, I\'m Digoal.Zhou, Just do it!',  
'digoal@126.com',  
276732431,  
clock_timestamp(),  
NULL;  
  
insert into user_session_0 (userid) select generate_series(1,4000000);  
insert into user_session_1 (userid) select generate_series(4000001,8000000);  
insert into user_session_2 (userid) select generate_series(8000001,12000000);  
insert into user_session_3 (userid) select generate_series(12000001,16000000);  
insert into user_session_4 (userid) select generate_series(16000001,20000000);  
  

```

pgfincore

```
select * from pgfadvise_willneed('user_info_0');
select * from pgfadvise_willneed('user_info_0_pkey');
select * from pgfadvise_willneed('user_info_1');
select * from pgfadvise_willneed('user_info_1_pkey');
select * from pgfadvise_willneed('user_info_2');
select * from pgfadvise_willneed('user_info_2_pkey');
select * from pgfadvise_willneed('user_info_3');
select * from pgfadvise_willneed('user_info_3_pkey');
select * from pgfadvise_willneed('user_info_4');
select * from pgfadvise_willneed('user_info_4_pkey');

select * from pgfadvise_willneed('user_session_0');
select * from pgfadvise_willneed('user_session_0_pkey');
select * from pgfadvise_willneed('user_session_1');
select * from pgfadvise_willneed('user_session_1_pkey');
select * from pgfadvise_willneed('user_session_2');
select * from pgfadvise_willneed('user_session_2_pkey');
select * from pgfadvise_willneed('user_session_3');
select * from pgfadvise_willneed('user_session_3_pkey');
select * from pgfadvise_willneed('user_session_4');
select * from pgfadvise_willneed('user_session_4_pkey');

select * from pgfadvise_willneed('pg_toast.' || (select relname from pg_class where oid=(select reltoastrelid from pg_class where relname='user_info_0')));
select * from pgfadvise_willneed('pg_toast.' || (select relname from pg_class where oid=(select reltoastrelid from pg_class where relname='user_info_1')));
select * from pgfadvise_willneed('pg_toast.' || (select relname from pg_class where oid=(select reltoastrelid from pg_class where relname='user_info_2')));
select * from pgfadvise_willneed('pg_toast.' || (select relname from pg_class where oid=(select reltoastrelid from pg_class where relname='user_info_3')));
select * from pgfadvise_willneed('pg_toast.' || (select relname from pg_class where oid=(select reltoastrelid from pg_class where relname='user_info_4')));
```

存储过程

```
create or replace function f_user_login_0  
(i_userid int,  
OUT o_userid int,  
OUT o_engname text,  
OUT o_cnname text,  
OUT o_occupation text,  
OUT o_birthday date,  
OUT o_signname text,  
OUT o_email text,  
OUT o_qq numeric  
)  
as $BODY$  
declare  
begin  
select userid,engname,cnname,occupation,birthday,signname,email,qq  
into o_userid,o_engname,o_cnname,o_occupation,o_birthday,o_signname,o_email,o_qq  
from user_info_0 where userid=i_userid;  
insert into user_login_rec (userid,login_time,ip) values (i_userid,now(),inet_client_addr());  
update user_session_0 set logintime=now(),login_count=login_count+1 where userid=i_userid;  
return;  
end;  
$BODY$  
language plpgsql;  
  
create or replace function f_user_login_1  
(i_userid int,  
OUT o_userid int,  
OUT o_engname text,  
OUT o_cnname text,  
OUT o_occupation text,  
OUT o_birthday date,  
OUT o_signname text,  
OUT o_email text,  
OUT o_qq numeric  
)  
as $BODY$  
declare  
begin  
select userid,engname,cnname,occupation,birthday,signname,email,qq  
into o_userid,o_engname,o_cnname,o_occupation,o_birthday,o_signname,o_email,o_qq  
from user_info_1 where userid=i_userid;  
insert into user_login_rec (userid,login_time,ip) values (i_userid,now(),inet_client_addr());  
update user_session_1 set logintime=now(),login_count=login_count+1 where userid=i_userid;  
return;  
end;  
$BODY$  
language plpgsql;  
  
create or replace function f_user_login_2  
(i_userid int,  
OUT o_userid int,  
OUT o_engname text,  
OUT o_cnname text,  
OUT o_occupation text,  
OUT o_birthday date,  
OUT o_signname text,  
OUT o_email text,  
OUT o_qq numeric  
)  
as $BODY$  
declare  
begin  
select userid,engname,cnname,occupation,birthday,signname,email,qq  
into o_userid,o_engname,o_cnname,o_occupation,o_birthday,o_signname,o_email,o_qq  
from user_info_2 where userid=i_userid;  
insert into user_login_rec (userid,login_time,ip) values (i_userid,now(),inet_client_addr());  
update user_session_2 set logintime=now(),login_count=login_count+1 where userid=i_userid;  
return;  
end;  
$BODY$  
language plpgsql;  
  
create or replace function f_user_login_3  
(i_userid int,  
OUT o_userid int,  
OUT o_engname text,  
OUT o_cnname text,  
OUT o_occupation text,  
OUT o_birthday date,  
OUT o_signname text,  
OUT o_email text,  
OUT o_qq numeric  
)  
as $BODY$  
declare  
begin  
select userid,engname,cnname,occupation,birthday,signname,email,qq  
into o_userid,o_engname,o_cnname,o_occupation,o_birthday,o_signname,o_email,o_qq  
from user_info_3 where userid=i_userid;  
insert into user_login_rec (userid,login_time,ip) values (i_userid,now(),inet_client_addr());  
update user_session_3 set logintime=now(),login_count=login_count+1 where userid=i_userid;  
return;  
end;  
$BODY$  
language plpgsql;  
  
create or replace function f_user_login_4  
(i_userid int,  
OUT o_userid int,  
OUT o_engname text,  
OUT o_cnname text,  
OUT o_occupation text,  
OUT o_birthday date,  
OUT o_signname text,  
OUT o_email text,  
OUT o_qq numeric  
)  
as $BODY$  
declare  
begin  
select userid,engname,cnname,occupation,birthday,signname,email,qq  
into o_userid,o_engname,o_cnname,o_occupation,o_birthday,o_signname,o_email,o_qq  
from user_info_4 where userid=i_userid;  
insert into user_login_rec (userid,login_time,ip) values (i_userid,now(),inet_client_addr());  
update user_session_4 set logintime=now(),login_count=login_count+1 where userid=i_userid;  
return;  
end;  
$BODY$  
language plpgsql;  
  
create or replace function f_user_logout_0  
(i_userid int,  
OUT o_result int  
)  
as $BODY$  
declare  
begin  
insert into user_logout_rec (userid,logout_time,ip) values (i_userid,now(),inet_client_addr());  
update user_session_0 set logouttime=now(),online_interval=online_interval+(now()-logintime) where userid=i_userid;  
o_result := 0;  
return;  
exception   
when others then  
o_result := 1;  
return;  
end;  
$BODY$  
language plpgsql;  
  
create or replace function f_user_logout_1  
(i_userid int,  
OUT o_result int  
)  
as $BODY$  
declare  
begin  
insert into user_logout_rec (userid,logout_time,ip) values (i_userid,now(),inet_client_addr());  
update user_session_1 set logouttime=now(),online_interval=online_interval+(now()-logintime) where userid=i_userid;  
o_result := 0;  
return;  
exception   
when others then  
o_result := 1;  
return;  
end;  
$BODY$  
language plpgsql;  
  
create or replace function f_user_logout_2  
(i_userid int,  
OUT o_result int  
)  
as $BODY$  
declare  
begin  
insert into user_logout_rec (userid,logout_time,ip) values (i_userid,now(),inet_client_addr());  
update user_session_2 set logouttime=now(),online_interval=online_interval+(now()-logintime) where userid=i_userid;  
o_result := 0;  
return;  
exception   
when others then  
o_result := 1;  
return;  
end;  
$BODY$  
language plpgsql;  
  
create or replace function f_user_logout_3  
(i_userid int,  
OUT o_result int  
)  
as $BODY$  
declare  
begin  
insert into user_logout_rec (userid,logout_time,ip) values (i_userid,now(),inet_client_addr());  
update user_session_3 set logouttime=now(),online_interval=online_interval+(now()-logintime) where userid=i_userid;  
o_result := 0;  
return;  
exception   
when others then  
o_result := 1;  
return;  
end;  
$BODY$  
language plpgsql;  
  
create or replace function f_user_logout_4  
(i_userid int,  
OUT o_result int  
)  
as $BODY$  
declare  
begin  
insert into user_logout_rec (userid,logout_time,ip) values (i_userid,now(),inet_client_addr());  
update user_session_4 set logouttime=now(),online_interval=online_interval+(now()-logintime) where userid=i_userid;  
o_result := 0;  
return;  
exception   
when others then  
o_result := 1;  
return;  
end;  
$BODY$  
language plpgsql;  
```

pgbench

```
cat login0.sql
\set userid random(1, 4000000)  
SELECT f_user_login_0(:userid);  
\set userid random(4000001, 8000000)
SELECT f_user_login_1(:userid);  
\set userid random(8000001, 12000000)  
SELECT f_user_login_2(:userid);  
\set userid random(12000001, 16000000)  
SELECT f_user_login_3(:userid);  
\set userid random(16000001, 20000000)  
SELECT f_user_login_4(:userid);  

cp login0.sql login1.sql
cp login0.sql login2.sql
cp login0.sql login3.sql
cp login0.sql login4.sql
```



```
pgbench -M simple -r -c 1 -f ./login0.sql -j 1 -n -T 180 -h 127.0.0.1 -p 8400 tuning &
pgbench -M simple -r -c 1 -f ./login1.sql -j 1 -n -T 180 -h 127.0.0.1 -p 8400 tuning &
pgbench -M simple -r -c 2 -f ./login2.sql -j 2 -n -T 180 -h 127.0.0.1 -p 8400 tuning &
pgbench -M simple -r -c 2 -f ./login3.sql -j 2 -n -T 180 -h 127.0.0.1 -p 8400 tuning &
pgbench -M simple -r -c 2 -f ./login4.sql -j 2 -n -T 180 -h 127.0.0.1 -p 8400 tuning &

```

结果

```
总tps不过1000，测试环境为4核心处理器，CPU已经严重瓶颈。该测试暂缓。
```



## 分配不同表空间



## hotstandby读写分离



## plproxy横向分库

select能力可以通过数据库流复制扩展, 9.2以后可以级联复制因此基本上可以做到不影响主库性能的情况下无限扩展.

insert、update能力可以通过将表拆分到多个服务器上, 无限扩展.



横向分库,需要考虑跨库事务的问题,



## 其他

\1. 批量提交,降低IO请求量, 并发请求很高的场景. 但是当并发场景这么高的时候已经可以考虑增加服务器分库了.

相关参数

```
#commit_delay = 0  
#commit_siblings = 5  

```

参考《Test PostgreSQL 9.1's group commit》

<http://blog.163.com/digoal@126/blog/static/1638770402011102214142132/>

\2. 连接池,如pgbouncer(适用于短连接, 大量空闲连接的情况.)

\3. 绑定变量, 性能提升参考

《how many performance decreased use dynamic SQL》

<http://blog.163.com/digoal@126/blog/static/1638770402011109103953350/>

\4. user_session中记录了用户的登陆统计信息和退出统计信息, 由于MVCC特性, 每次更新都会新产生一条tuple, 因此如果将登陆和退出的统计拆开, 就能减少新增的tuple的大小. 一定程度上提升性能.

```
user_session_login (userid, logintime, login_count)  
user_session_logout (userid, logouttime, online_interval)  

```

\5. OS级别也有可以优化的地方, 比如文件系统的mount参数可以加上noatime.

\6. 服务器硬件也有可以优化的地方, 比如numa.

\7. PostgreSQL也还有可以微调的参数, 比如bgwriter_lru_maxpages和bgwriter_lru_multiplier它们的值也将影响数据库和文件系统交互的频率以及每次交互产生的io请求数.

\8. 在做分表优化的时候, 本例使用的是按userid分段拆分成了5个表. 其实还可以按hash取模拆, 按时间段拆等等. 拆分的关键是尽量按照常用的条件字段进行拆分. 另外需要注意的是, 我这里没有提到PostgreSQL的partition table的实现, 而是直接使用应用端来识别数据在哪个分区. 原因是PostgreSQL的partition table需要通过rule或者触发器来实现, 大量的消耗数据库服务器的CPU, 不推荐使用. 性能下降和Oracle的比较可参考,



