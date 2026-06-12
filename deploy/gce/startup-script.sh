#!/usr/bin/env bash
# GCE startup script: installs Docker + Compose and runs WordPress + WooCommerce.
# Runs automatically on first boot. Logs: /var/log/syslog and `docker compose logs`.
set -euxo pipefail

# --- Install Docker Engine + compose plugin (Debian/Ubuntu image) ------------
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# --- Write the compose stack (port 80 -> WordPress) --------------------------
mkdir -p /opt/store
cat > /opt/store/docker-compose.yml <<'YAML'
services:
  db:
    image: mariadb:lts
    restart: unless-stopped
    environment:
      MARIADB_DATABASE: wordpress
      MARIADB_USER: wordpress
      MARIADB_PASSWORD: wordpress
      MARIADB_ROOT_PASSWORD: rootpassword
    volumes:
      - db_data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
      interval: 10s
      timeout: 5s
      retries: 20

  wordpress:
    image: wordpress:latest
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    ports:
      - "80:80"
    environment:
      WORDPRESS_DB_HOST: db:3306
      WORDPRESS_DB_NAME: wordpress
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_PASSWORD: wordpress
    volumes:
      - wp_data:/var/www/html

  cli:
    image: wordpress:cli
    depends_on:
      wordpress:
        condition: service_started
    environment:
      WORDPRESS_DB_HOST: db:3306
      WORDPRESS_DB_NAME: wordpress
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_PASSWORD: wordpress
    volumes:
      - wp_data:/var/www/html
    entrypoint: ["tail", "-f", "/dev/null"]

volumes:
  db_data:
  wp_data:
YAML

cd /opt/store
docker compose up -d db wordpress

# Install + activate WooCommerce once WordPress is reachable.
for i in $(seq 1 60); do
  if curl -fsS http://localhost:80/ >/dev/null 2>&1; then break; fi
  sleep 5
done
docker compose run --rm cli wp plugin install woocommerce --activate --allow-root || true

echo "store-startup-complete"
