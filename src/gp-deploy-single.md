# Greenplum单机调试环境部署

Gaomingjie - May 2018

## 背景

记录安装greenplum-db-5.8.0过程

## 安装记录

规划



### 系统

```
# yum -y install rsync coreutils glib2 lrzsz sysstat e4fsprogs xfsprogs ntp readline-devel zlib zlib-devel openssl openssl-devel pam-devel libxml2-devel libxslt-devel python-devel tcl-devel gcc make smartmontools flex bison perl perl-devel perl-ExtUtils* OpenIPMI-tools openldap openldap-devel logrotate python-py gcc-c++ libevent-devel apr-devel libcurl-devel bzip2-devel libyaml-devel  

yum install ninja-build

# vi /etc/sysctl.conf  
kernel.shmmax = 500000000
kernel.shmmni = 4096
kernel.shmall = 4000000000
kernel.sem = 250 512000 100 2048
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
  
# sysctl -p  
  
# vi /etc/security/limits.conf  
* soft nofile 65536
* hard nofile 65536
* soft nproc 131072
* hard nproc 131072

  
# rm -f /etc/security/limits.d/90-nproc.conf  
```

安装cmake3

```
wget https://cmake.org/files/v3.11/cmake-3.11.3-Linux-x86_64.sh
ln -s /home/jackgo/projects/cmake-3.11.3-Linux-x86_64/bin/cmake /usr/local/bin/cmake
```

调整ssh

```shell
ssh-keygen xxx
cp ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# Verify that you can ssh to your machine name without a password
ssh <hostname of your machine>
```

调整ldconfig

```
cat >> /etc/ld.so.conf <<-EOF
/usr/local/lib
/usr/local/lib64
EOF
ldconfig
```

### 安装gporca

```shell
wget https://github.com/greenplum-db/gporca/archive/v2.59.1.tar.gz
tar xzvf v2.59.1.tar.gz
cd gporca-2.59.1
cmake -GNinja -H. -Bbuild
cd build
ninja-build -j8
sudo ninja-build install > install.log
```



### 安装编译

安装依赖库

```
# vim 
...
pip ... -i http://pypi.douban.com/simple --trusted-host pypi.douban.com
...

# ./README.CentOS.bash
```
开始安装

```shell
wget https://github.com/greenplum-db/gpdb/archive/5.8.0.tar.gz
tar -xzvf 5.8.0.tar.gz
cd gpdb
./configure --prefix=$HOME/databases/gpdb9400
```

