#!/bin/bash

#########################################
# KS GAMING PANEL INSTALLER - FULL SYSTEM
# (Merged & upgraded: Tailscale auto-detect,
#  Nginx installer, Panel troubleshooting)
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
echo "7) Install Nginx (for Panel)"
echo "8) Panel Troubleshoot / Fix"
echo "0) Exit"
echo "-------------------------------------"
read -p "Select an option [0-8]: " option

case $option in
    1) install_panel ;;
    2) install_wings ;;
    3) install_panel; install_wings ;;
    4) install_cloudflare ;;
    5) install_tailscale ;;
    6) uninstall_menu ;;
    7) install_nginx ;;
    8) panel_troubleshoot ;;
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

read -p "Enter your panel domain or IP (example: panel.example.com or 1.2.3.4): " panelDomain
read -p "Do you want to create admin user? (yes/no): " makeAdmin

if [[ "$makeAdmin" == "yes" ]]; then
    read -p "Admin Email: " adminEmail
    read -p "Admin Username: " adminUser
    read -p "Admin Password: " adminPass
fi

echo "[1/8] Updating system..."
apt update -y && apt upgrade -y

echo "[2/8] Installing dependencies..."
apt install -y curl wget git zip unzip tar mariadb-server php php-cli php-common php-curl php-mysql php-gd php-mbstring php-xml php-bcmath php-json php-zip php-fpm

echo "[3/8] Setting up panel directory..."
mkdir -p /var/www/pterodactyl
cd /var/www/pterodactyl

echo "[4/8] Downloading Pterodactyl Panel..."
curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
tar -xzvf panel.tar.gz
chmod -R 755 storage bootstrap/cache || true

echo "[5/8] Installing Composer..."
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/bin/composer
composer install --no-dev --optimize-autoloader || true

echo "[6/8] Configuring Panel..."
cp .env.example .env
php artisan key:generate --force || true

DB_PASS=$(openssl rand -hex 12)

mysql -u root -e "CREATE USER 'ptero'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -u root -e "CREATE DATABASE IF NOT EXISTS panel;"
mysql -u root -e "GRANT ALL PRIVILEGES ON panel.* TO 'ptero'@'localhost';"
mysql -u root -e "FLUSH PRIVILEGES;"

php artisan p:environment:database --host=127.0.0.1 --port=3306 --database=panel --username=ptero --password="$DB_PASS" || true

# Set APP_URL to http (Cloudflare/Tunnel friendly)
php artisan p:environment:setup \
    --url="http://$panelDomain" \
    --author="$adminEmail" \
    --timezone="Asia/Kolkata" \
    --cache="file" \
    --session="file" \
    --queue="sync" || true

echo "[7/8] Running migrations..."
php artisan migrate --seed --force || true

if [[ "$makeAdmin" == "yes" ]]; then
php artisan p:user:make \
    --email="$adminEmail" \
    --username="$adminUser" \
    --name-first="Admin" \
    --name-last="User" \
    --password="$adminPass" \
    --admin=1 || true
fi

echo "[8/8] Finalizing permissions..."
chown -R www-data:www-data /var/www/pterodactyl || true

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

systemctl daemon-reload 2>/dev/null || true
systemctl enable wings 2>/dev/null || true
systemctl start wings 2>/dev/null || true

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

mkdir -p --mode=0755 /usr/share/keyrings

curl -fsSL https://pkg.cloudflare.com/cloudflare-public-v2.gpg \
    | tee /usr/share/keyrings/cloudflare-public-v2.gpg >/dev/null

echo 'deb [signed-by=/usr/share/keyrings/cloudflare-public-v2.gpg] https://pkg.cloudflare.com/cloudflared any main' \
    | tee /etc/apt/sources.list.d/cloudflared.list

apt-get update
apt-get install -y cloudflared

echo ""
echo "===== CLOUDFLARED INSTALLED ====="
echo "Use: cloudflared tunnel login"
sleep 2
main_menu
}

#########################################
# INSTALL TAILSCALE (auto-detect and clickable login)
#########################################

install_tailscale() {
    clear
    echo "===== INSTALLING TAILSCALE ====="

    # Detect OS
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        CODENAME=${VERSION_CODENAME:-$UBUNTU_CODENAME}
        IDNAME=${ID:-ubuntu}
    else
        echo "Cannot detect OS. Aborting Tailscale install."
        sleep 2
        main_menu
        return
    fi

    echo "Detected: $NAME ($IDNAME $CODENAME)"

    # Build gpg and list URLs based on detection (supports ubuntu & debian)
    GPG_URL="https://pkgs.tailscale.com/stable/${IDNAME}/${CODENAME}.noarmor.gpg"
    LIST_URL="https://pkgs.tailscale.com/stable/${IDNAME}/${CODENAME}.tailscale-noarmor.list"

    # Try to fetch repo files (will fail gracefully if unsupported)
    if ! curl -fsSL "$GPG_URL" > /dev/null 2>&1; then
        echo "Tailscale repo not available for ${IDNAME}/${CODENAME}. Trying 'debian' fallback..."
        GPG_URL="https://pkgs.tailscale.com/stable/debian/bookworm.noarmor.gpg"
        LIST_URL="https://pkgs.tailscale.com/stable/debian/bookworm.tailscale-noarmor.list"
    fi

    # Add key and repo
    curl -fsSL "$GPG_URL" | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
    curl -fsSL "$LIST_URL" | sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null

    apt update
    apt install -y tailscale || {
        echo "Tailscale installation failed or unsupported OS."
        sleep 2
        main_menu
        return
    }

    # Start tailscaled (use systemctl if available, fallback to service)
    if command -v systemctl >/dev/null 2>&1; then
        systemctl enable tailscaled 2>/dev/null || true
        systemctl start tailscaled 2>/dev/null || true
    else
        service tailscaled start 2>/dev/null || true
    fi

    echo ""
    echo "Getting Tailscale login URL..."
    echo ""

    # Run tailscale up and capture login URL (it prints URL to stderr/stdout)
    LOGIN_URL=$(sudo tailscale up 2>&1 | grep -o "https://login.tailscale.com/[^ ]*" | head -n1)

    if [ -z "$LOGIN_URL" ]; then
        echo "Could not automatically get a login URL. Try running 'sudo tailscale up' manually on the server."
    else
        echo "To authenticate this device, click the link below:"
        echo ""
        echo "➡️  $LOGIN_URL"
        echo ""
    fi

    echo "=============================================="
    sleep 3
    main_menu
}

#########################################
# INSTALL NGINX (simple Pterodactyl config)
#########################################

install_nginx() {
    clear
    echo "===== INSTALLING NGINX & CREATING SITE FOR PTERODACTYL ====="
    read -p "Enter the panel domain or IP you want Nginx to serve (example: panel.example.com or 1.2.3.4): " nginxDomain

    apt update
    apt install -y nginx

    # detect php-fpm socket version (common versions)
    PHP_SOCK=""
    if [ -S /run/php/php8.1-fpm.sock ]; then
        PHP_SOCK="/run/php/php8.1-fpm.sock"
    elif [ -S /run/php/php8.2-fpm.sock ]; then
        PHP_SOCK="/run/php/php8.2-fpm.sock"
    elif [ -S /run/php/php7.4-fpm.sock ]; then
        PHP_SOCK="/run/php/php7.4-fpm.sock"
    else
        # fallback: use tcp
        PHP_SOCK="127.0.0.1:9000"
    fi

    cat <<EOF >/etc/nginx/sites-available/pterodactyl
server {
    listen 80;
    server_name ${nginxDomain};

    root /var/www/pterodactyl/public;
    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_pass ${PHP_SOCK};
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

    ln -sf /etc/nginx/sites-available/pterodactyl /etc/nginx/sites-enabled/pterodactyl
    nginx -t || true

    # restart services with fallback
    if command -v systemctl >/dev/null 2>&1; then
        systemctl restart nginx 2>/dev/null || true
        # try to restart php-fpm services we detected
        if [ -S /run/php/php8.1-fpm.sock ]; then systemctl restart php8.1-fpm 2>/dev/null || true; fi
        if [ -S /run/php/php8.2-fpm.sock ]; then systemctl restart php8.2-fpm 2>/dev/null || true; fi
    else
        service nginx restart 2>/dev/null || true
    fi

    echo "Nginx installed and site created for ${nginxDomain}. Visit http://${nginxDomain}"
    sleep 2
    main_menu
}

#########################################
# PANEL TROUBLESHOOT / FIX
#########################################

panel_troubleshoot() {
    clear
    echo "===== PANEL TROUBLESHOOT / FIX ====="
    echo "This will run a few checks and show logs."
    read -p "Enter your panel directory (default: /var/www/pterodactyl) or press enter: " PANEL_DIR
    PANEL_DIR=${PANEL_DIR:-/var/www/pterodactyl}

    if [ ! -d "$PANEL_DIR" ]; then
        echo "Panel directory not found: $PANEL_DIR"
        sleep 2
        main_menu
        return
    fi

    echo ""
    echo "-> php artisan p:info (if available)"
    cd "$PANEL_DIR" || true
    if command -v php >/dev/null 2>&1; then
        php artisan p:info || echo "artisan p:info failed or not available."
    else
        echo "php not found on PATH."
    fi
    echo ""
    echo "-> Check PHP-FPM service status (common versions):"
    for v in 8.2 8.1 7.4; do
        svc="php${v}-fpm"
        if command -v systemctl >/dev/null 2>&1; then
            systemctl status $svc --no-pager -n 5 2>/dev/null || true
        else
            service $svc status 2>/dev/null || true
        fi
    done

    echo ""
    echo "-> Check nginx status"
    if command -v systemctl >/dev/null 2>&1; then
        systemctl status nginx --no-pager -n 5 2>/dev/null || service nginx status 2>/dev/null || true
    else
        service nginx status 2>/dev/null || true
    fi

    echo ""
    echo "-> Last 120 lines of nginx error log (if exists):"
    if [ -f /var/log/nginx/error.log ]; then
        tail -n 120 /var/log/nginx/error.log
    else
        echo "No /var/log/nginx/error.log found."
    fi

    echo ""
    echo "-> Last 120 lines of php-fpm log (if exists):"
    if [ -f /var/log/php8.1-fpm.log ]; then
        tail -n 120 /var/log/php8.1-fpm.log
    else
        echo "No /var/log/php8.1-fpm.log found - check php-fpm logs in /var/log or journalctl."
    fi

    echo ""
    echo "If panel still doesn't load, share the above output or run:"
    echo " - cd $PANEL_DIR && php artisan migrate --seed --force"
    echo " - tail -f /var/log/nginx/error.log"
    echo " - journalctl -u php8.1-fpm -n 200 --no-pager"
    echo ""
    read -p "Press enter to return to menu..." tmp
    main_menu
}

#########################################
# UNINSTALL FUNCTIONS
#########################################

uninstall_panel() {
    clear
    echo "===== UNINSTALLING PANEL ====="
    # stop php-fpm services if possible
    if command -v systemctl >/dev/null 2>&1; then
        systemctl stop php8.2-fpm 2>/dev/null || true
        systemctl stop php8.1-fpm 2>/dev/null || true
    else
        service php8.2-fpm stop 2>/dev/null || true
        service php8.1-fpm stop 2>/dev/null || true
    fi

    rm -rf /var/www/pterodactyl
    mysql -u root -e "DROP DATABASE IF EXISTS panel;" >/dev/null 2>&1 || true
    mysql -u root -e "DROP USER IF EXISTS 'ptero'@'localhost';" >/dev/null 2>&1 || true

    echo "Panel removed!"
    sleep 2
}

uninstall_wings() {
    clear
    echo "===== UNINSTALLING WINGS ====="
    if command -v systemctl >/dev/null 2>&1; then
        systemctl stop wings 2>/dev/null || true
        systemctl disable wings 2>/dev/null || true
    else
        service wings stop 2>/dev/null || true
    fi

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
