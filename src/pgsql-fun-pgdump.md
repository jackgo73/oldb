# pg_dump几种导出方式测试

> JackGao
>
> Email: jackgo73@outlook.com
>
> Date:  20180417

## 背景

今天在邮件列表上有人在问怎样用pg_dump快速导出数据并灌入远程服务器，他的库比较大。所以整个过程中最慢的过程应该是网络传输这部分，所以应尽量减小传输的数据量，并使操作不要太复杂。

## 构造测试数据

构造**随机测试数据**模拟导出时的数据情况


```sql
postgres=# select pg_size_pretty(pg_database_size('postgres'));
 pg_size_pretty 
----------------
 7535 kB
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
insert into t1 select generate_series(1,12000000),md5(random()::text),clock_timestamp();
insert into t2 select generate_series(1,11500000),md5(random()::text),clock_timestamp();
insert into t3 select generate_series(1,11000000),md5(random()::text),clock_timestamp();
insert into t4 select generate_series(1,13000000),md5(random()::text),clock_timestamp();
insert into t5 select generate_series(1,14000000),md5(random()::text),clock_timestamp();
insert into t6 select generate_series(1,11000000),md5(random()::text),clock_timestamp();
insert into t7 select generate_series(1,11000000),md5(random()::text),clock_timestamp();
insert into t8 select generate_series(1,15000000),md5(random()::text),clock_timestamp();
...

postgres=# select pg_size_pretty(pg_database_size('postgres'));
 pg_size_pretty 
----------------
 7201 MB
(1 row)
```

## 几种导出方式测试

### 环境

Intel(R) Core(TM) i5-4250U CPU @ 1.30GHz  单块金士顿SSD 120GB  8G内存

```
Architecture:          x86_64
CPU op-mode(s):        32-bit, 64-bit
Byte Order:            Little Endian
CPU(s):                4
Model name:            Intel(R) Core(TM) i5-4250U CPU @ 1.30GHz

Model Family:     SandForce Driven SSDs
Device Model:     KINGSTON SV300S37A120G
Serial Number:    50026B775110E78C
LU WWN Device Id: 5 0026b7 75110e78c
Firmware Version: 600ABBF0
User Capacity:    120,034,123,776 bytes [120 GB]
Sector Size:      512 bytes logical/physical
Rotation Rate:    Solid State Device
```

### 1 一般导出

不进行任何压缩，IO 100%

```
[jackgo@localhost ~/databases/data][00]$ date;pg_dump postgres > outfile.sql;date;
Tue Apr 17 03:12:22 EDT 2018
Tue Apr 17 03:28:25 EDT 2018
[jackgo@localhost ~/databases/data][00]$ du -sh *
6.3G	outfile.sql
8.1G	pgdata8400
```

### 2 导出压缩（GZIP）

gzip压缩，CPU 100%

```
[jackgo@localhost ~/databases/data][00]$ date;pg_dump postgres | gzip > outfile.gz;date;
Tue Apr 17 03:31:11 EDT 2018
Tue Apr 17 03:36:38 EDT 2018
[jackgo@localhost ~/databases/data][00]$ du -sh *
2.4G	outfile.gz
8.1G	pgdata8400
```

### 3 导出定制格式的压缩包（ZLIB）

内置zlib压缩，CPU 100%。调整压缩比并没有什么用。

```
[jackgo@localhost ~/databases/data][00]$ date;pg_dump -Fc postgres > outfile.dump;date;
Tue Apr 17 03:59:26 EDT 2018
Tue Apr 17 04:04:59 EDT 2018
[jackgo@localhost ~/databases/data][00]$ du -sh *
2.4G	outfile.dump
8.1G	pgdata8400

[jackgo@localhost ~/databases/data][00]$ date;pg_dump -Fc -Z 9 postgres > outfile.dump;date;
Tue Apr 17 04:18:51 EDT 2018
Tue Apr 17 04:30:50 EDT 2018
[jackgo@localhost ~/databases/data][00]$ du -sh *
2.4G	outfile.dump
8.1G	pgdata8400
```

### 4 导出定制格式的压缩包（TAR）

目录格式的归档文件，不支持压缩

```
[jackgo@localhost ~/databases/data][00]$ date;pg_dump -Ft postgres > outfile.dump;date;
Tue Apr 17 04:09:21 EDT 2018
Tue Apr 17 04:12:04 EDT 2018
[jackgo@localhost ~/databases/data][00]$ du -sh *
6.3G	outfile.dump
8.1G	pgdata8400
```

### 5 导出定制格式的压缩包（目录，支持并发）

和Fc的区别就是每个表分别做了压缩，生成多个文件在dumpdir中。

```
[jackgo@localhost ~/databases/data][00]$ date;pg_dump -Fd postgres -f dumpdir;date
Tue Apr 17 04:35:28 EDT 2018
Tue Apr 17 04:40:45 EDT 2018
2.4G	dumpdir
8.1G	pgdata8400
```

并发测试来一发

（4核CPU跑满%Cpu0  : 98.3 us,  %Cpu1  : 97.7 us,  %Cpu2  : 98.3 us,  %Cpu3  : 97.3 us）

```
[jackgo@localhost ~/databases/data][00]$ date;pg_dump -Fd -j 4 postgres -f dumpdir;date
Tue Apr 17 04:44:03 EDT 2018
Tue Apr 17 04:46:53 EDT 2018
[jackgo@localhost ~/databases/data][00]$ du -sh *
2.4G	dumpdir
8.1G	pgdata8400
```

## 总结

在7.2GB数据量的数据库下，I5 8G SSD硬盘的测试结果（仅供参考）。

>  ps. 输出文件除了-Fp和直接无参pg_dump的方式外，都需要使用pg_restore灌入

| command                                  | export time | output size |
| ---------------------------------------- | ----------- | ----------- |
| pg_dump postgres > outfile.sql           | 16m23s      | 6.3 GB      |
| pg_dump postgres \| gzip > outfile.gz    | 5m27s       | 2.4 GB      |
| pg_dump -Fc postgres > outfile.dump      | 5m33s       | 2.4 GB      |
| pg_dump -Fc -Z 9 postgres > outfile.dump | 11m59s      | 2.4 GB      |
| pg_dump -Ft postgres > outfile.dump      | 2m43s       | 6.3 GB      |
| pg_dump -Fd postgres -f dumpdir          | 5m17s       | 2.4 GB      |
| pg_dump -Fd -j 4 postgres -f dumpdir     | 2m50s       | 2.4 GB      |

综上，时间空间上导出的最优方案为：

```pg_dump -Fd -j 4 postgres -f dumpdir```

原因比较简单：并发+压缩。



**(测试机器性能较差，结果仅供参考。)**

## 参考

构造测试数据：https://github.com/digoal/blog/blob/master/201711/20171121_01.md

pg_dump：https://www.postgresql.org/docs/9.6/static/backup-dump.html#BACKUP-DUMP-RESTORE



```
                 command                  | export_time | output_size 
------------------------------------------+-------------+-------------
 pg_dump postgres > outfile.sql           | 16m23s      | 6.3 GB
 pg_dump postgres | gzip > outfile.gz     | 5m27s       | 2.4 GB
 pg_dump -Fc postgres > outfile.dump      | 5m33s       | 2.4 GB
 pg_dump -Fc -Z 9 postgres > outfile.dump | 11m59s      | 2.4 GB
 pg_dump -Ft postgres > outfile.dump      | 2m43s       | 6.3 GB
 pg_dump -Fd postgres -f dumpdir          | 5m17s       | 2.4 GB
 pg_dump -Fd -j 4 postgres -f dumpdir     | 2m50s       | 2.4 GB
(7 rows)

```

