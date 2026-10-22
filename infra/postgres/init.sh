#!/bin/sh
set -eu

psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  --set=app_password="$APP_DB_PASSWORD" \
  --set=metrics_password="$METRICS_DB_PASSWORD" <<'SQL'
CREATE ROLE billing_app LOGIN PASSWORD :'app_password';
CREATE ROLE billing_metrics LOGIN PASSWORD :'metrics_password';
GRANT pg_monitor TO billing_metrics;
ALTER DATABASE billing OWNER TO billing_app;
GRANT ALL ON SCHEMA public TO billing_app;
SQL
