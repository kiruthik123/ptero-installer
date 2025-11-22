#!/bin/bash

#########################################
# KS GAMING PANEL INSTALLER - FULL SYSTEM
#########################################

# ASCII Banner
clear
echo -e "\e[96m"
echo "██╗  ██╗███████╗     ███████╗ █████╗  ██████╗ ███╗   ███╗██╗███╗   ██╗ ██████╗ "
echo "██║ ██╔╝██╔════╝     ██╔════╝██╔══██╗██╔════╝ ████╗ ████║██║████╗  ██║██╔════╝ "
echo "█████╔╝ █████╗       ███████╗███████║██║  ███╗██╔████╔██║██║██╔██╗ ██║██║  ███╗"
echo "██╔═██╗ ██╔══╝       ╚════██║██╔══██║██║   ██║██║╚██╔╝██║██║██║╚██╗██║██║   ██║"
echo "██║  ██╗███████╗     ███████║██║  ██║╚██████╔╝██║ ╚═╝ ██║██║██║ ╚████║╚██████╔╝"
echo "╚═╝  ╚═╝╚══════╝     ╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝╚═╝╚═╝  ╚═══╝ ╚═════╝ "
echo -e "                             \e[92mKS GAMING INSTALLER\e[0m"
echo -e "\e[0m"
sleep 1

TITLE1="🛠️ KS PANEL INSTALLER"
TITLE2="   created by KS GAMING"

#########################################
# MAIN MENU
#########################################

main_menu() {
clear
echo -e "\e[36m$TITLE1\e[0m"
echo -e "\e[90m$TITLE2\e[0m"
echo "-------------------------------------"
echo "1) Install Panel"
echo "2) Install Wings"
echo "3) Install Panel + Wings"
echo "4) Install Cloudflare (cloudflared)"
echo "5) Install Tailscale"
echo "6) Uninstall Tool"
echo "0) Exit"
echo "-------------------------------------"
read -p "Select an option [0-6]: " option

case $option in
    1) install_panel ;;
    2) install_wings ;;
    3) install_panel; install_wings ;;
    4) install_cloudflare ;;
    5) install_tailscale ;;
    6) uninstall_menu ;;
    0) exit ;;
    *) echo "Invalid choice!"; sleep 1; main_menu ;;
esac
}

#########################################
# INSTALL PANEL
#########################################

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
sleep 3
main_menu
}

#########################################
# INSTALL WINGS
#########################################

install_wings() {
clear
echo "===== WINGS INSTALLATION ====="

read -p "Enter Wings Domain or IP: " wingsDomain
read -p "Enter Wings UUID: " wingsUUID
read -p "Enter Wings Token ID: " wingsTokenID
read -p "Enter Wings Token: " wingsToken
read -p "Enter Remote Base URL (http://panel.example.com): " remoteBase

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
echo "========================================"
sleep 3
main_menu
}

#########################################
# INSTALL CLOUDFLARED
#########################################

install_cloudflare() {
clear
echo "===== INSTALLING CLOUDFLARED ====="

sudo mkdir -p --mode=0755 /usr/share/keyrings

curl -fsSL https://pkg.cloudflare.com/cloudflare-public-v2.gpg \
    | sudo tee /usr/share/keyrings/cloudflare-public-v2.gpg >/dev/null

echo 'deb [signed-by=/usr/share/keyrings/cloudflare-public-v2.gpg] https://pkg.cloudflare.com/cloudflared any main' \
    | sudo tee /etc/apt/sources.list.d/cloudflared.list

sudo apt-get update
sudo apt-get install -y cloudflared

echo ""
echo "===== CLOUDFLARED INSTALLED ====="
echo "Use: cloudflared tunnel login"
sleep 2
main_menu
}

#########################################
# INSTALL TAILSCALE (CLICKABLE LOGIN)
#########################################

install_tailscale() {
clear
echo "===== INSTALLING TAILSCALE ====="

curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.noarmor.gpg \
    | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null

curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.tailscale-noarmor.list \
    | sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null

sudo apt update
sudo apt install -y tailscale

sudo systemctl enable tailscaled
sudo systemctl start tailscaled

echo ""
echo "Getting Tailscale login URL..."
echo ""

LOGIN_URL=$(sudo tailscale up 2>&1 | grep -o "https://.*")

echo "To authenticate this device, click the link below:"
echo ""
echo "➡️  $LOGIN_URL"
echo ""
echo "=============================================="
sleep 3
main_menu
}

#########################################
# UNINSTALL FUNCTIONS
#########################################

uninstall_panel() {
    clear
    echo "===== UNINSTALLING PANEL ====="
    systemctl stop php* >/dev/null 2>&1
    rm -rf /var/www/pterodactyl
    mysql -u root -e "DROP DATABASE panel;" >/dev/null 2>&1
    mysql -u root -e "DROP USER 'ptero'@'localhost';" >/dev/null 2>&1
    echo "Panel removed!"
    sleep 2
}

uninstall_wings() {
    clear
    echo "===== UNINSTALLING WINGS ====="
    systemctl stop wings >/dev/null 2>&1
    systemctl disable wings >/dev/null 2>&1
    rm -rf /etc/pterodactyl
    rm -rf /etc/systemd/system/wings.service
    rm -rf /var/lib/pterodactyl
    echo "Wings removed!"
    sleep 2
}

uninstall_all() {
    uninstall_panel
    uninstall_wings
    echo "All components removed!"
    sleep 2
}

uninstall_menu() {
    clear
    echo "===== UNINSTALL TOOL ====="
    echo "1) Uninstall Panel"
    echo "2) Uninstall Wings"
    echo "3) Uninstall All"
    echo "4) Go Back"
    read -p "Select an option [1-4]: " uninstall_option

    case $uninstall_option in
        1) uninstall_panel ;;
        2) uninstall_wings ;;
        3) uninstall_all ;;
        4) main_menu ;;
        *) echo "Invalid choice!"; sleep 1; uninstall_menu ;;
    esac
}

#########################################
# START
#########################################

main_menu
