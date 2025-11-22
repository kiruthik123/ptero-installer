#!/bin/bash

TITLE1="🛠️ KS PANEL INSTALLER"
TITLE2="   created by KS GAMING"

main_menu() {
clear
echo -e "\e[36m$TITLE1\e[0m"
echo -e "\e[90m$TITLE2\e[0m"
echo "-------------------------------------"
echo "1) Panel Installation"
echo "2) Wings Installation"
echo "3) Panel + Wings"
echo "0) Exit"
echo "-------------------------------------"
read -p "Select an option [0-3]: " option

case $option in
    1) install_panel ;;
    2) install_wings ;;
    3) install_panel; install_wings ;;
    0) exit ;;
    *) echo "Invalid choice!"; sleep 1; main_menu ;;
esac
}

install_panel() {
clear
echo "===== PANEL INSTALLATION ====="

read -p "Enter your panel domain (example: panel.example.com): " panelDomain
read -p "Do you want to create admin user? (yes/no): " makeAdmin

if [[ "$makeAdmin" == "yes" ]]; then
    read -p "Admin Email: " adminEmail
    read -p "Admin Username: " adminUser
    read -p "Admin Password: " adminPass
fi

echo "[1/6] Updating system..."
apt update -y && apt upgrade -y

echo "[2/6] Installing dependencies..."
apt install -y curl wget git zip unzip tar mariadb-server php php-cli php-common php-curl php-mysql php-gd php-mbstring php-xml php-bcmath php-json php-zip php-fpm

echo "[3/6] Setting up panel directory..."
mkdir -p /var/www/pterodactyl
cd /var/www/pterodactyl

echo "[4/6] Downloading Pterodactyl Panel..."
curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
tar -xzvf panel.tar.gz
chmod -R 755 storage bootstrap/cache

echo "[5/6] Installing Composer..."
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/bin/composer
composer install --no-dev --optimize-autoloader

echo "[6/6] Configuring Panel..."
cp .env.example .env
php artisan key:generate --force

DB_PASS=$(openssl rand -hex 12)

mysql -u root -e "CREATE USER 'ptero'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -u root -e "CREATE DATABASE panel;"
mysql -u root -e "GRANT ALL PRIVILEGES ON panel.* TO 'ptero'@'localhost';"
mysql -u root -e "FLUSH PRIVILEGES;"

php artisan p:environment:database --host=127.0.0.1 --port=3306 --database=panel --username=ptero --password="$DB_PASS"

php artisan p:environment:setup \
    --url="http://$panelDomain" \
    --author="$adminEmail" \
    --timezone="Asia/Kolkata" \
    --cache="file" \
    --session="file" \
    --queue="sync"

php artisan migrate --seed --force

if [[ "$makeAdmin" == "yes" ]]; then
php artisan p:user:make \
    --email="$adminEmail" \
    --username="$adminUser" \
    --name-first="Admin" \
    --name-last="User" \
    --password="$adminPass" \
    --admin=1
fi

echo ""
echo "===== PANEL INSTALLED SUCCESSFULLY ====="
echo "Panel URL: http://$panelDomain"
echo "MySQL Password: $DB_PASS"
echo "========================================"
}

install_wings() {
clear
echo "===== WINGS INSTALLATION ====="

read -p "Enter Wings Domain or IP (e.g., node.example.com or 45.x.x.x): " wingsDomain
read -p "Enter Wings UUID: " wingsUUID
read -p "Enter Wings Token ID: " wingsTokenID
read -p "Enter Wings Token: " wingsToken
read -p "Enter Remote Base URL (example: http://panel.example.com): " remoteBase

echo "[1/4] Installing Docker..."
curl -fsSL https://get.docker.com | sh

echo "[2/4] Downloading Wings..."
mkdir -p /etc/pterodactyl
cd /etc/pterodactyl
curl -Lo wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
chmod +x wings

echo "[3/4] Creating Wings config.yml..."

cat <<EOF >/etc/pterodactyl/config.yml
debug: false

uuid: "$wingsUUID"
token_id: "$wingsTokenID"
token: "$wingsToken"

api:
  host: 0.0.0.0
  port: 8080

system:
  data: /var/lib/pterodactyl/volumes

docker:
  network:
    name: pterodactyl_nw

remote:
  base: "$remoteBase"
EOF

echo "[4/4] Enabling Wings..."

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

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable wings
systemctl start wings

echo ""
echo "===== WINGS INSTALLED SUCCESSFULLY ====="
echo "Wings URL: http://$wingsDomain:8080"
echo "UUID: $wingsUUID"
echo "Token ID: $wingsTokenID"
echo "Token: $wingsToken"
echo "Remote Base: $remoteBase"
echo "========================================"
}

main_menu
