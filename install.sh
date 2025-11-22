#!/bin/bash

echo "=============================="
echo "   KS PANEL INSTALLER (HTTP)"
echo "=============================="
sleep 1

echo ""
echo "Enter your domain (example: panel.ksgaming.in):"
read panelDomain

echo "Enter admin Gmail:"
read adminEmail

echo "Enter admin username:"
read adminUser

echo "Enter admin password:"
read adminPass

echo ""
echo "Starting installation..."
sleep 1

echo "[1/12] Updating system..."
apt update -y && apt upgrade -y

echo "[2/12] Installing required packages..."
apt install -y curl wget unzip git zip tar mariadb-server gnupg

echo "[3/12] Installing Docker..."
curl -fsSL https://get.docker.com | sh

echo "[4/12] Installing PHP..."
apt install -y php php-cli php-common php-curl php-mysql php-gd php-mbstring php-xml php-bcmath php-json php-zip php-fpm

echo "[5/12] Creating panel directory..."
mkdir -p /var/www/pterodactyl
cd /var/www/pterodactyl

echo "[6/12] Downloading Pterodactyl Panel..."
curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
tar -xzvf panel.tar.gz
chmod -R 755 storage/* bootstrap/cache/

echo "[7/12] Installing Composer..."
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/bin/composer

echo "[8/12] Running composer install..."
composer install --no-dev --optimize-autoloader

echo "[9/12] Setting environment..."
cp .env.example .env
php artisan key:generate --force

php artisan p:environment:setup \
    --author="$adminEmail" \
    --url="http://$panelDomain" \
    --timezone="Asia/Kolkata" \
    --cache="file" \
    --session="file" \
    --queue="sync"

echo "[10/12] Setting up database..."
DB_PASS=$(openssl rand -hex 12)

mysql -u root -e "CREATE USER 'ptero'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -u root -e "CREATE DATABASE panel;"
mysql -u root -e "GRANT ALL PRIVILEGES ON panel.* TO 'ptero'@'localhost';"
mysql -u root -e "FLUSH PRIVILEGES;"

php artisan p:environment:database \
    --host="127.0.0.1" \
    --port="3306" \
    --database="panel" \
    --username="ptero" \
    --password="$DB_PASS"

php artisan migrate --seed --force

echo "[11/12] Creating admin user..."
php artisan p:user:make \
    --email="$adminEmail" \
    --username="$adminUser" \
    --name-first="Admin" \
    --name-last="User" \
    --password="$adminPass" \
    --admin=1

echo "[12/12] Installing Wings..."
mkdir -p /etc/pterodactyl
cd /etc/pterodactyl
curl -Lo wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
chmod +x wings

cat <<EOF >/etc/systemd/system/wings.service
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
Requires=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
ExecStart=/etc/pterodactyl/wings
Restart=always
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable wings
systemctl start wings

echo ""
echo "=================================="
echo "     INSTALLATION COMPLETE!"
echo "=================================="
echo "Panel URL: http://$panelDomain"
echo "Admin Email: $adminEmail"
echo "Admin Username: $adminUser"
echo "Admin Password: $adminPass"
echo "Database Password: $DB_PASS"
echo ""
echo "Use Cloudflare Tunnel to connect your domain."
echo "=================================="
