# Notebook

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

## SwitchyOmega

```
https://raw.githubusercontent.com/gfwlist/gfwlist/master/gfwlist.txt
```

