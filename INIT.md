# Notebook

## xxx

```
vi /boot/grub2/grub.cfg
%s/UTF-8/UTF-8 vga=0x344

```

## Network

```
vi /etc/sysconfig/network-scripts/ifcfg-enp0s3

BOOTPROTO=static
ONBOOT=yes

DNS1=114.114.114.114
IPADDR=192.168.1.84
NETMASK=255.255.255.0
GATEWAY=192.168.1.1

systemctl restart netword.service

# for some other ports 
firewall-cmd --zone=public --add-port=80/tcp --permanent
firewall-cmd --reload 
```

## SSH

```
chkconfig sshd on
service sshd start
yum install net-tools bzip2 vim
```

## SMB

[《Centos Firewalld》](src/linux-centos-firewalld.md)

```
yum install samba samba-client 

vim /etc/samba/smb.conf
-->
[homes]
  comment = Home Directories
  browseable = Yes
  read only = No
  valid users = jackgo
smbpasswd -a jackgo
firewall-cmd --permanent --zone=public --add-service=samba
firewall-cmd --reload
setenforce 0
vi /etc/selinux/config
--> SELINUX=disabled
--> !! DO NOT CHANGE SELINUXTYPE

systemctl enable smb nmb
systemctl restart smb nmb
```

## Github

```
git config --global core.autocrlf false
git config --global user.email "jackgo73@outlook.com"
git config --global user.name "Jack Gao"
ssh-keygen -t rsa -b 4096 -C "jackgo73@outlook.com"

git config --global http.proxy 'socks5://127.0.0.1:1091' 
git config --global https.proxy 'socks5://127.0.0.1:1091'
```

## Chrome

```
cat << EOF > /etc/yum.repos.d/google-chrome.repo
[google-chrome]
name=google-chrome
baseurl=http://dl.google.com/linux/chrome/rpm/stable/\$basearch
enabled=1
gpgcheck=1
gpgkey=https://dl-ssl.google.com/linux/linux_signing_key.pub
EOF

yum install google-chrome-stable -y --nogpgcheck
```

```
https://github.com/FelisCatus/SwitchyOmega/releases/download/v2.5.15/SwitchyOmega.crx
https://raw.githubusercontent.com/gfwlist/gfwlist/master/gfwlist.txt
```

## Rescue

```
grub2 press 'e'

find 'linux16 ... ro'

change to 'linux16 ... rw init /sysboot/bin/sh '

ctrl + x

chroot/sysroot/

```


