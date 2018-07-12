# perf大法好

参考文章链接：

[Linux 性能诊断 perf使用指南](https://github.com/digoal/blog/blob/master/201611/20161127_01.md)

[PostgreSQL 源码性能诊断(perf profiling)指南](https://github.com/digoal/blog/blob/master/201611/20161129_01.md)

## 安装perf

### 环境

```
[jackgo@localhost blog]$ cat /etc/redhat-release 
CentOS Linux release 7.5.1804 (Core)

[jackgo@localhost blog]$ uname -a
Linux localhost.localdomain 3.10.0-862.2.3.el7.x86_64 #1 SMP Wed May 9 18:05:47 UTC 2018 x86_64 x86_64 x86_64 GNU/Linux

[jackgo@localhost blog]$ cat /proc/version
Linux version 3.10.0-862.2.3.el7.x86_64 (builder@kbuilder.dev.centos.org) (gcc version 4.8.5 20150623 (Red Hat 4.8.5-28) (GCC) ) #1 SMP Wed May 9 18:05:47 UTC 2018
```

### 下载内核

```shell
wget -S https://mirrors.edge.kernel.org/pub/linux/kernel/v3.x/linux-3.10.86.tar.gz
tar -xzvf linux-3.10.86.tar.gz
cd linux-3.10.86/tools/perf/
```
### 安装依赖包

```
yum install perf
```

---



源码安装：

```
[root@localhost perf]# cat Makefile |grep found
		msg := $(warning No libelf found, disables 'probe' tool, please install elfutils-libelf-devel/libelf-dev);
		msg := $(error No gnu/libc-version.h found, please install glibc-dev[el]/glibc-static);
		msg := $(warning No libdw.h found or old libdw.h found or elfutils is older than 0.138, disables dwarf support. Please install new elfutils-devel/libdw-dev);
	msg := $(warning No libunwind found, disabling post unwind support. Please install libunwind-dev[el] >= 0.99);
		msg := $(warning No libaudit.h found, disables 'trace' tool, please install audit-libs-devel or libaudit-dev);
		msg := $(warning slang not found, disables TUI support. Please install slang-devel or libslang-dev);
		msg := $(warning GTK2 not found, disables GTK2 support. Please install gtk2-devel or libgtk2.0-dev);
  $(if $(1),$(warning No $(1) was found))
						msg := $(warning No bfd.h/libbfd found, install binutils-dev[el]/zlib-static to gain symbol demangling)
		msg := $(warning No numa.h found, disables 'perf bench numa mem' benchmark, please install numa-libs-devel or libnuma-dev);
		
[root@localhost perf]# cat Makefile |awk '/found/'|awk -F 'found' '{print $1}'|awk -F 'No' '{print $2}'
 libelf 
 gnu/libc-version.h 
 libdw.h 
 libunwind 
 libaudit.h 


 $(1) was 
 bfd.h/libbfd 
 numa.h
```

安装

```shell
yum install -y gcc make bison flex elfutils elfutils-libelf-devel libdwarf-devel audit-libs-devel python-devel binutils-devel
```







临时记录

诊断pg_stat_statements

参数配置

```
shared_preload_libraries='pg_stat_statements'  
track_io_timing = on                     # 启用对系统 I/O 调用的计时
track_activity_query_size = 2048         # 跟踪当前SQL的保留字节数，用于pg_stat_activity的query
pg_stat_statements.max = 10000           # 最多保留
pg_stat_statements.track = all           # 所有SQL内嵌的
pg_stat_statements.track_utility = off   # 只记录DML
pg_stat_statements.save = on             # 重启保留信息
```

### 最耗IO SQL

单次调用最耗IO SQL TOP 5

```
select userid::regrole, dbid, query from pg_stat_statements order by (blk_read_time+blk_write_time)/calls desc limit 5;  

```

总最耗IO SQL TOP 5

```
select userid::regrole, dbid, query from pg_stat_statements order by (blk_read_time+blk_write_time) desc limit 5;  

```

### 最耗时 SQL

单次调用最耗时 SQL TOP 5

```
select userid::regrole, dbid, query from pg_stat_statements order by mean_time desc limit 5;  

```

总最耗时 SQL TOP 5

```
select userid::regrole, dbid, query from pg_stat_statements order by total_time desc limit 5;  

```

### 响应时间抖动最严重 SQL

```
select userid::regrole, dbid, query from pg_stat_statements order by stddev_time desc limit 5;  

```

### 最耗共享内存 SQL

```
select userid::regrole, dbid, query from pg_stat_statements order by (shared_blks_hit+shared_blks_dirtied) desc limit 5;  

```

### 最耗临时空间 SQL

```
select userid::regrole, dbid, query from pg_stat_statements order by temp_blks_written desc limit 5;  
```