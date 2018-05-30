# Greenplum单机调试环境部署

Gaomingjie - May 2018

## 背景

参考https://github.com/digoal/blog/blob/master/201512/20151217_01.md

记录安装greenplum-db-5.8.0过程

## 安装记录

规划



### 系统

```
# yum -y install rsync coreutils glib2 lrzsz sysstat e4fsprogs xfsprogs ntp readline-devel zlib zlib-devel openssl openssl-devel pam-devel libxml2-devel libxslt-devel python-devel tcl-devel gcc make smartmontools flex bison perl perl-devel perl-ExtUtils* OpenIPMI-tools openldap openldap-devel logrotate python-py gcc-c++ libevent-devel apr-devel libcurl-devel bzip2-devel libyaml-devel  

# vi /etc/sysctl.conf  
kernel.shmmax = 68719476736  
kernel.shmmni = 4096  
kernel.shmall = 4000000000  
kernel.sem = 50100 64128000 50100 1280  
kernel.sysrq = 1  
kernel.core_uses_pid = 1  
kernel.msgmnb = 65536  
kernel.msgmax = 65536  
kernel.msgmni = 2048  
net.ipv4.tcp_syncookies = 1  
net.ipv4.ip_forward = 0  
net.ipv4.conf.default.accept_source_route = 0  
net.ipv4.tcp_tw_recycle = 1  
net.ipv4.tcp_max_syn_backlog = 4096  
net.ipv4.conf.all.arp_filter = 1  
net.ipv4.ip_local_port_range = 1025 65535  
net.core.netdev_max_backlog = 10000  
net.core.rmem_max = 2097152  
net.core.wmem_max = 2097152  
vm.overcommit_memory = 2  
fs.file-max = 7672460  
net.ipv4.netfilter.ip_conntrack_max = 655360  
fs.aio-max-nr = 1048576  
net.ipv4.tcp_keepalive_time = 72   
net.ipv4.tcp_keepalive_probes = 9   
net.ipv4.tcp_keepalive_intvl = 7  
  
# sysctl -p  
  
# vi /etc/security/limits.conf  
* soft nofile 131072    
* hard nofile 131072    
* soft nproc 131072   
* hard nproc 131072  
* soft    memlock unlimited  
* hard    memlock unlimited  
  
# rm -f /etc/security/limits.d/90-nproc.conf  
```



### 安装编译

```
git clone https://github.com/greenplum-db/gpdb.git
cd gpdb
./configure --prefix=$HOME/databases/gpdb9400
```

提示错误

```
configure: error: library xerces-c is required to build with Pivotal Query Optimizer
```

处理：