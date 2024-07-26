#!/bin/bash

# Set nameserver google, cloudflare
echo -e "nameserver 8.8.8.8\nnameserver 1.1.1.1" > /etc/resolv.conf

# Enable TCP BBR congestion control
cat <<EOF > /etc/sysctl.conf
# TCP BBR congestion control
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF

# update 
sudo apt update -y
sudo apt install htop -y
sudo apt install nano -y
sudo apt install zip -y
sudo apt install unzip -y
sudo apt install screen -y
sudo apt install wget -y
sudo apt install curl -y
sudo apt install gpg -y

# Set time Viet Nam
timedatectl set-timezone Asia/Ho_Chi_Minh

# setup swapfile
sudo fallocate -l 1G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
sudo cp /etc/fstab /etc/fstab.bak
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
cat <<EOF > /etc/sysctl.d/99-xs-swappiness.conf
vm.swappiness=10
EOF

# setup frankenphp 
set -e

wget -q "https://github.com/dunglas/frankenphp/releases/download/v1.2.2/frankenphp-linux-$(uname -m)"

install -v "frankenphp-linux-$(uname -m)" "/usr/bin/frankenphp"
rm "frankenphp-linux-$(uname -m)"

if [[ ! $(grep -F "frankenphp" /etc/group) ]]
then
    groupadd --system frankenphp 
fi

if [[ ! $(grep -F "frankenphp" /etc/passwd) ]]
then
    useradd --system --gid frankenphp --create-home  --home-dir /var/lib/frankenphp --shell /usr/sbin/nologin frankenphp
fi

mkdir -p /etc/frankenphp

if [ ! -f "/etc/frankenphp/Caddyfile" ];
then
    echo -e "{\n}" > /etc/frankenphp/Caddyfile
fi

chown -R frankenphp:frankenphp /etc/frankenphp/

cat<<EOF > /etc/systemd/system/frankenphp.service
[Unit]
Description=FrankenPHP Server
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=notify
User=frankenphp
Group=frankenphp
ExecStartPre=/usr/bin/frankenphp validate --config /etc/frankenphp/Caddyfile
ExecStart=/usr/bin/frankenphp run --environ --config /etc/frankenphp/Caddyfile
ExecReload=/usr/bin/frankenphp reload --config /etc/frankenphp/Caddyfile --force
TimeoutStopSec=5s
LimitNOFILE=1048576
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

systemctl enable --now frankenphp

# more
mkdir -p /data/www/default
mkdir -p /var/log/caddy/
mkdir -p /var/lib/php/opcache
mkdir -p /etc/caddy/conf.d/
chown -R frankenphp:frankenphp /data/www/default
chown -R frankenphp:frankenphp /var/log/caddy/
chown -R frankenphp:frankenphp /etc/caddy/
chown -R frankenphp:frankenphp /etc/ssl
chown root.frankenphp /var/lib/php/opcache

wget --no-check-certificate https://raw.githubusercontent.com/bibicadotnet/LCMP-Minimal/main/Caddyfile -O /etc/frankenphp/Caddyfile
systemctl restart frankenphp

# setup wp-cli
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp

# Create symbolic link
ln -s /var/www /root/
ln -s /etc/caddy /root/

