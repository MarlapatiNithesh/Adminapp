#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/opt/app"
CONF_FILE="$APP_DIR/nginx/conf.d/upstreams.generated.conf"
SERVICE="express-app-admin"   # base service name, we’ll catch replicas

# Find all running containers for this service family
IPS=$(docker ps --filter "name=${SERVICE}" --format '{{.ID}}' \
  | xargs -r -I{} docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' {} \
  | sort)

# Write upstream config
{
  echo "upstream app_upstream {"
  for ip in $IPS; do
    echo "  server ${ip}:5000;"
  done
  echo "}"
} > "$CONF_FILE"

# Ensure Nginx includes the generated upstream file
if ! grep -q "upstreams.generated.conf" "$APP_DIR/nginx/conf.d/app.conf"; then
  echo "include /etc/nginx/conf.d/upstreams.generated.conf;" >> "$APP_DIR/nginx/conf.d/app.conf"
fi

# Reload nginx
docker compose -f "$APP_DIR/docker-compose.yml" exec -T nginx nginx -s reload || true

echo "Upstream list updated in $CONF_FILE:"
cat "$CONF_FILE"
