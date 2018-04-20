---
title: Postgresql-HA
date: 2017-06-02 11:43:58
categories: Postgresql
tags: 
    - postgresql
    - ha
---

## 部署架构

![](images/pgsql-fun-ha-0.jpg)

## 主机配置
（主机ID20）
```

sed -ir "s/#*max_replication_slots.*/max_replication_slots= 10/" $PGDATA/postgresql.conf

sed -ir "s/#*max_wal_senders.*/max_wal_senders = 10/" $PGDATA/postgresql.conf
sed -ir "s/#*wal_level.*/wal_level = replica/" $PGDATA/postgresql.conf
sed -ir "s/#*archive_mode.*/archive_mode = on/" $PGDATA/postgresql.conf
sed -ir "s/#*archive_command.*/archive_command = 'test ! -f \${PGHOME}\/archive\/%f \&\& cp %p \${PGHOME}\/archive\/%f'/" $PGDATA/postgresql.conf
```

## 归档恢复服务器配置
（ID21）

### 制作基础备份（主节点操作）
> **注意1：如果使用initdb后的数据库做归档，会报错**
> LOG:  WAL file is from different database system
> **注意2：为什么归档？**
> 如果你使用的流复制没有基于文件的连续归档，该服务器可能在后备机收到 WAL 段之前回收这些旧的 WAL 段。如果发生这种情况，后备机将需要重新从一个新的基础备 份初始化。通过设置wal_keep_segments为一个足够高的值来确保旧 的 WAL 段不会被太早重用或者为后备机配置一个复制槽，可以避免发生这种情况。如果设置了一个后备机可以访问的 WAL归档，就不需要这些解决方案，因为该归档可以 为后备机保留足够的段，后备机总是可以使用该归档来追赶主控机。

第一步：配置pg_hba.conf通道

第二步：`pg_basebackup -Fp -P -x -D ~/app/data/pg_root21 -l basebackup21`

### 配置归档恢复
```
cp $PGHOME/share/recovery.conf.sample ./recovery.conf
sed -ir "s/#*standby_mode.*/standby_mode= on/" $PGDATA/recovery.conf
sed -ir "s/#*restore_command.*/restore_command = 'cp \/home\/gaomingjie\/app\/pgsql20\/archive\/%f %p'/" $PGDATA/recovery.conf
```
备机日志（不停的获取最新日志）：
```
cp: cannot stat `/home/gaomingjie/app/pgsql20/archive/000000010000000000000004': No such file or directory
cp: cannot stat `/home/gaomingjie/app/pgsql20/archive/000000010000000000000004': No such file or directory
cp: cannot stat `/home/gaomingjie/app/pgsql20/archive/000000010000000000000004': No such file or directory
cp: cannot stat `/home/gaomingjie/app/pgsql20/archive/000000010000000000000004': No such file or directory
cp: cannot stat `/home/gaomingjie/app/pgsql20/archive/000000010000000000000004': No such file or directory
LOG:  restored log file "000000010000000000000004" from archive
cp: cannot stat `/home/gaomingjie/app/pgsql20/archive/000000010000000000000005': No such file or directory
cp: cannot stat `/home/gaomingjie/app/pgsql20/archive/000000010000000000000005': No such file or directory
cp: cannot stat `/home/gaomingjie/app/pgsql20/archive/000000010000000000000005': No such file or directory
```
进程状态：
```
/home/gaomingjie/app/pgsql21/bin/postgres
\_ postgres: startup process   recovering 000000010000000000000005
\_ postgres: checkpointer process           
\_ postgres: writer process
```

## 流复制异步服务器配置
（ID22）
> 默认情况下流复制是异步的，在这种情况下主服务器上提交一个事务与该变化在后备服务器上变得可见之间存在短暂的延迟。不过这种延迟比基于文件的日志传送方式中要小得多，在后备服务器的能力足以跟得上负载的前提下延迟通常低于一秒。在流复制中，不需要archive_timeout来缩减数据丢失窗口。在支持 keepalive 套接字选项的系统上，设置tcp_keepalives_idle、tcp_keepalives_interval和tcp_keepalives_count有助于主服务器迅速地注意到一个断开的连接。

### 制作基础备份（主节点操作）

第一步：配置pg_hba.conf通道
>设置好用于复制的访问权限非常重要，这样只有受信的用户可以读取 WAL 流，因为很容易从 WAL 流中抽取出需要特权才能访问的信息。后备服务器必须作为一个超级用户或一个具有REPLICATION特权的账户向主服务器认证。我们推荐为复制创建一个专用的具有REPLICATION和LOGIN特权的用户账户。虽然REPLICATION特权给出了非常高的权限，但它不允许用户修改主系统上的任何数据，而SUPERUSER特权则可以。
```flow
op1=>operation: primary_conninfo= 'host=127.0.0.1 port=9420'
op2=>operation: pg_hba.conf
op2->op1
```
```
配置方法1（本例中不使用这种配置方法）:

pg_hba.conf:

host    replication     gaomingjie        127.0.0.1/32            trust

配置方法2(创建用户后使用密码校验)：

create role foo login replication password 'server@123';

pg_hba.conf:

host    replication     foo               127.0.0.1/32            md5
```
第二步：`pg_basebackup -Fp -P -x -D ~/app/data/pg_root22 -l basebackup22`

### 配置流复制参数
```
cp $PGHOME/share/recovery.conf.sample ./recovery.conf
sed -ir "s/#*standby_mode.*/standby_mode= on/" $PGDATA/recovery.conf
sed -ir "s/#*primary_conninfo.*/primary_conninfo= 'host=127.0.0.1 port=9420 user=foo password=server@123'/" $PGDATA/recovery.conf
```
日志信息
```
LOG:  database system was shut down in recovery at 2017-04-27 11:46:42 CST
LOG:  entering standby mode
LOG:  redo starts at 0/6000028
LOG:  consistent recovery state reached at 0/7000000
LOG:  started streaming WAL from primary at 0/7000000 on timeline 1
```
进程状态
```
/home/gaomingjie/app/pgsql22/bin/postgres
\_ postgres: startup process   recovering 000000010000000000000007
\_ postgres: checkpointer process           
\_ postgres: writer process                 
\_ postgres: wal receiver process   streaming 0/7000140
```

### 监控流复制状态

> 　　流复制的一个重要健康指标是在主服务器上产生但还没有在后备服务器上应用的 WAL 记录数。你可以通过比较主服务器上的当前 WAL 写位置和后备服务器接收到的最后一个 WAL 位置来计算这个滞后量。
> 　　它们分别可以用主服务器上的pg_current_xlog_location和后备服务器上的pg_last_xlog_receive_location来检索。后备服务器的最后 WAL 接收位置也被显示在 WAL 接收者进程的进程状态中，即使用ps命令显示的状态。
> 　　你 可 以 通 过**pg_stat_replication**视 图 检 索 WAL 发 送 者 进 程 的 列表。pg_current_xlog_location与sent_location域之间的巨大差异表示主服务器承受着巨大的负载，**而sent_location和后备服务器上pg_last_xlog_receive_location之间的差异可能表示网络延迟或者后备服务器正承受着巨大的负载**。
```
postgres=# select * from pg_stat_replication;
-[ RECORD 1 ]----+-----------------------------
pid              | 11715
usesysid         | 16393
usename          | foo
application_name | walreceiver
client_addr      | 127.0.0.1
client_hostname  | 
client_port      | 51930
backend_start    | 2017-04-27 14:12:57.43909+08
backend_xmin     | 
state            | streaming
sent_location    | 0/8000610
write_location   | 0/8000610
flush_location   | 0/8000610
replay_location  | 0/8000610
sync_priority    | 0
sync_state       | async
```


## 流复制槽异步热备服务器配置（级联主）
（ID23）

### 制作基础备份（主节点操作）

第一步：权限配置
```
create role foo login replication password 'server@123';

pg_hba.conf:

host    replication     foo               127.0.0.1/32            md5
```
第二步：`pg_basebackup -Fp -P -x -D ~/app/data/pg_root23 -l basebackup23`

第三步：主节点创建流复制槽
```
SELECT * FROM pg_create_physical_replication_slot('node_slot_23');

SELECT * FROM pg_replication_slots;
-[ RECORD 1 ]-------+-------------
slot_name           | node_slot_23
plugin              | 
slot_type           | physical
datoid              | 
database            | 
active              | f
active_pid          | 
xmin                | 
catalog_xmin        | 
restart_lsn         | 
confirmed_flush_lsn |
```

### 配置流复制参数
```
sed -ir "s/#*hot_standby.*/hot_standby= on/" $PGDATA/postgresql.conf

cp $PGHOME/share/recovery.conf.sample ./recovery.conf
sed -ir "s/#*standby_mode.*/standby_mode= on/" $PGDATA/recovery.conf
sed -ir "s/#*primary_conninfo.*/primary_conninfo= 'host=127.0.0.1 port=9420 user=foo password=server@123'/" $PGDATA/recovery.conf
sed -ir "s/#*primary_slot_name.*/primary_slot_name= 'node_slot_23'/" $PGDATA/recovery.conf
```
日志信息
```
LOG:  entering standby mode
LOG:  redo starts at 0/9000028
LOG:  consistent recovery state reached at 0/A000060
LOG:  invalid record length at 0/A000060: wanted 24, got 0
LOG:  database system is ready to accept read only connections
LOG:  started streaming WAL from primary at 0/A000000 on timeline 1
```
进程状态
```
/home/gaomingjie/app/pgsql23/bin/postgres
\_ postgres: startup process   recovering 00000001000000000000000A
\_ postgres: checkpointer process           
\_ postgres: writer process                 
\_ postgres: stats collector process        
\_ postgres: wal receiver process
```
主节点查询流复制槽状态
```
psql
psql (9.6.0)
Type "help" for help.

postgres=# \x
Expanded display is on.
postgres=# SELECT * FROM pg_replication_slots;
-[ RECORD 1 ]-------+-------------
slot_name           | node_slot_23
plugin              | 
slot_type           | physical
datoid              | 
database            | 
active              | t
active_pid          | 14799
xmin                | 
catalog_xmin        | 
restart_lsn         | 0/B001148
confirmed_flush_lsn |

psql -U foo -W "dbname=postgres replication=database" 
Password for user foo: 
psql (9.6.0)
Type "help" for help.

postgres=> IDENTIFY_SYSTEM;
      systemid       | timeline |  xlogpos  |  dbname  
---------------------+----------+-----------+----------
 6413518490021561706 |        1 | 0/B001148 | postgres
(1 row)

```

### 流复制槽概念
>  　　复制槽提供了一种自动化的方法来确保主控机在所有的后备机收到 WAL 段 之前不会移除它们，并且主控机也不会移除可能导致 恢复冲突的行，即使后备机断开也是如此。
>  　　作 为 复 制 槽 的 替 代 ， 也 可 以 使 用wal_keep_segments 阻 止 移 除 旧 的 WAL 段 ，或 者 使用archive_command 把段保存在一个归档中。不过，这些方法常常会导致保留的 WAL 段比需要的 更多，而复制槽只保留已知所需要的段。这些方法的一个优点是它们为 pg_xlog的空间需求提供了界限，但目前使用复制槽无法做到。
>  　　类似地，hot_standby和 vacuum_defer_cleanup_age保护了相关行不被 vacuum 移除，但是前者在后备机断开期间无法提供保护，而后者则需要被设置为一个很高 的值已提供足够的保护。复制槽克服了这些缺点。

#### 查询和操纵复制槽
　　每个复制槽都有一个名字，名字可以包含小写字母、数字和下划线字符。已有的复制槽和它们的状态可以在 pg_replication_slots 视图中看到。

[**流复制槽相关函数**](https://www.postgresql.org/docs/9.6/static/functions-admin.html#FUNCTIONS-REPLICATION)

```
pg_create_physical_replication_slot
pg_drop_replication_slot
pg_create_logical_replication_slot
pg_logical_slot_get_changes
pg_logical_slot_peek_changes
pg_logical_slot_get_binary_changes
pg_logical_slot_peek_binary_changes
pg_replication_origin_create
pg_replication_origin_drop
pg_replication_origin_oid
pg_replication_origin_session_setup
pg_replication_origin_session_reset
pg_replication_origin_session_is_setup
pg_replication_origin_session_progress
pg_replication_origin_xact_setup
pg_replication_origin_xact_reset
pg_replication_origin_advance
pg_replication_origin_progress
pg_logical_emit_message
```

## 级联备异步服务器配置
（ID24）
### 制作基础备份（主节点23操作）
`pg_basebackup -U foo -W -Fp -P -x -D ~/app/data/pg_root24 -l basebackup24`

注：这里连接23去做基础备份。
### 配置流复制参数
```
sed -ir "s/#*standby_mode.*/standby_mode= on/" $PGDATA/recovery.conf
sed -ir "s/#*primary_conninfo.*/primary_conninfo= 'host=127.0.0.1 port=9423 user=foo password=server@123'/" $PGDATA/recovery.conf
```
日志信息
```
LOG:  database system was interrupted while in recovery at log time 2017-04-28 11:13:33 CST
HINT:  If this has occurred more than once some data might be corrupted and you might need to choose an earlier recovery target.
LOG:  entering standby mode
LOG:  redo starts at 0/B00D958
LOG:  consistent recovery state reached at 0/B00DA38
LOG:  invalid record length at 0/B00DA38: wanted 24, got 0
LOG:  database system is ready to accept read only connections
LOG:  started streaming WAL from primary at 0/B000000 on timeline 1
```
进程状态
```
/home/gaomingjie/app/pgsql23/bin/postgres
\_ postgres: startup process   recovering 00000001000000000000000B
\_ postgres: checkpointer process           
\_ postgres: writer process                 
\_ postgres: stats collector process        
\_ postgres: wal receiver process   streaming 0/B00DBF8
\_ postgres: wal sender process foo 127.0.0.1(58019) streaming 0/B00DBF8

/home/gaomingjie/app/pgsql24/bin/postgres
\_ postgres: startup process   recovering 00000001000000000000000B
\_ postgres: checkpointer process           
\_ postgres: writer process                 
\_ postgres: stats collector process        
\_ postgres: wal receiver process   streaming 0/B00DBF8
```

## 流复制同步热备服务器配置（开启归档）
（ID25）
>　　在请求同步复制时，一个写事务的每次提交将一直等待，直到收到一个确认表明该提交在主服务器和后备服务器上都已经被写入到磁盘上的事务日志中。数据会被丢失的唯一可能性是主服务器和后备服务器在同一时间都崩溃。这可以提供更高级别的持久性，尽管只有系统管理员要关系两台服务器的放置和管理。等待确认提高了用户对于修改不会丢失的信心，但是同时也不必要地增加了对请求事务的响应时间。最小等待时间是在主服务器和后备服务器之间的来回时间。只读事务和事务回滚不需要等待后备服务器的回复。子事务提交也不需要等待后备服务器的响应，只有顶层提交才需要等待。长时间运行的动作（如数据载入或索引构建）不会等待最后的提交消息。所有两阶段提交动作要求提交等待，包括预备和提交。
>
### 制作基础备份（主节点20操作）

第一步：权限配置
```
create role foo login replication password 'server@123';

pg_hba.conf:

host    replication     foo               127.0.0.1/32            md5
```

第二步：`pg_basebackup -U foo -W -Fp -P -x -D ~/app/data/pg_root25 -l basebackup25`

注：这里连接20去做基础备份。

第三步：修改synchronous_standby_names参数。
```
sed -ir "s/#*synchronous_standby_names.*/synchronous_standby_names= '1 (s1)'/" $PGDATA/postgresql.conf
```



### 配置流复制参数
```
sed -ir "s/#*hot_standby.*/hot_standby= on/" $PGDATA/postgresql.conf

cp $PGHOME/share/recovery.conf.sample ./recovery.conf
sed -ir "s/#*standby_mode.*/standby_mode= on/" $PGDATA/recovery.conf
sed -ir "s/#*primary_conninfo.*/primary_conninfo= 'application_name=s1 host=127.0.0.1 port=9420 user=foo password=server@123'/" $PGDATA/recovery.conf

sed -ir "s/#*archive_mode.*/archive_mode = always/" $PGDATA/postgresql.conf
sed -ir "s/#*archive_command.*/archive_command = 'test ! -f \${PGHOME}\/archive\/%f \&\& cp %p \${PGHOME}\/archive\/%f'/" $PGDATA/postgresql.conf
```
主节点日志信息
```
LOG:  standby "s1" is now a synchronous standby with priority 1
```
主节点查询双机状态
```
postgres=# select * from pg_stat_replication where application_name='s1';
-[ RECORD 1 ]----+------------------------------
pid              | 23543
usesysid         | 16393
usename          | foo
application_name | s1
client_addr      | 127.0.0.1
client_hostname  | 
client_port      | 48481
backend_start    | 2017-04-28 14:45:03.051153+08
backend_xmin     | 
state            | streaming
sent_location    | 0/E0000D0
write_location   | 0/E0000D0
flush_location   | 0/E0000D0
replay_location  | 0/E0000D0
sync_priority    | 1
sync_state       | sync
```

### 相关参数
synchronous_commit
| values       | means                                    |
| ------------ | ---------------------------------------- |
| remote_apply | 当提交记录被重放时后备服务器会发送回应消息，这会让该事务变得可见。如果从主服务器的synchronous_standby_names优先列表中选中该后备服务器作为一个同步后备，将会根据来自该后备服务器和其他同步后备的回应消息来决定何时释放正在等待确认提交记录被收到的事务。这些参数允许管理员指定哪些后备服务器应该是同步后备。注意同步复制的配置主要在主控机上。命名的后备服务器必须直接连接到主控机，主控机对使用级联复制的下游后备服务器一无所知。<br> remote_apply导致每一次提交都会等待，直到当前的同步后备服务器报告说它们已经重放了该事务，这样就会使该事务对用户查询可见。在简单的情况下，这为带有因果一致性的负载均衡留出了余地。如果请求一次快速关闭，用户将停止等待。不过，在使用异步复制时，在所有未解决的WAL 记录被传输到当前连接的后备服务器之前，服务器将不会完全关闭。 |
| remote_write | 导致每次提交都等待后备服务器已经接收提交记录并将它写出到其自身所在的操作系统的确认，但并非等待数据都被刷出到后备服务器上的磁盘。这种设置提供了比on要弱一点的持久性保障：在一次操作系统崩溃事件中后备服务器可能丢失数据，尽管它不是一次PostgreSQL崩溃。不过，在实际中它是一种有用的设置，因为它可以减少事务的响应时间。只有当主服务器和后备服务器都崩溃并且主服务器的数据库同时被损坏的情况下，数据丢失才会发生。 |

---

后面有时间记录一些参数的使用经验。


