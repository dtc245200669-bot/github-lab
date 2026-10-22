#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

if [ -e .env ]; then
  echo ".env already exists; leaving its credentials unchanged." >&2
  exit 1
fi

secret() {
  openssl rand -hex 24
}

umask 077
cat > .env <<EOF
COMPOSE_PROJECT_NAME=billing-system
POSTGRES_USER=billing_admin
POSTGRES_PASSWORD=$(secret)
APP_DB_PASSWORD=$(secret)
METRICS_DB_PASSWORD=$(secret)
PGADMIN_DEFAULT_EMAIL=admin@example.com
PGADMIN_DEFAULT_PASSWORD=$(secret)
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=$(secret)
EOF
chmod 600 .env
echo "Created .env with random credentials. Keep it private; it is excluded from Git."
