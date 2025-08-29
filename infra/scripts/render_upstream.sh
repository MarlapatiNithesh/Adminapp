#!/usr/bin/env bash
set -Eeuo pipefail
set -x

# ================================
# Configuration
# ================================
APP_DIR="/opt/app"
UPSTREAMS_DIR="$APP_DIR/nginx/conf.d/upstreams"
OUT_FILE="$UPSTREAMS_DIR/node_upstream.conf"
SERVICE_PREFIX="express-app-admin"
NETWORK_NAME="${NETWORK_NAME:-app-net}"
APP_PORT="${APP_PORT:-5000}"

DOCKER="sudo docker"
DCOMPOSE="sudo docker compose -f $APP_DIR/docker-compose.yml"

# ================================
# Ensure directories
# ================================
mkdir -p "$UPSTREAMS_DIR"

# ================================
# Sanity checks
# ================================
cd "$APP_DIR"
[ -f docker-compose.yml ] || { echo "::error::docker-compose.yml missing"; exit 1; }
[ -f nginx/nginx.conf ] || { echo "::error::nginx/nginx.conf missing"; exit 1; }
[ -f nginx/conf.d/app.conf ] || { echo "::error::nginx/conf.d/app.conf missing"; exit 1; }

# ================================
# Docker check
# ================================
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker "$USER" || true
fi
sudo systemctl enable --now docker || true
$DOCKER --version
$DOCKER compose version || true

# ================================
# Docker login if private
# ================================
if [ -n "${DKR_USER:-}" ] && [ -n "${DKR_TOKEN:-}" ]; then
  echo "$DKR_TOKEN" | $DOCKER login -u "$DKR_USER" --password-stdin
fi

# ================================
# Replace placeholder image
# ================================
if grep -q "__DOCKER_HUB_IMAGE__" docker-compose.yml; then
  if [ -n "${DKR_USER:-}" ]; then
    sudo sed -i "s|__DOCKER_HUB_IMAGE__|$DKR_USER/admin-app:latest|g" docker-compose.yml
  else
    echo "::warning::__DOCKER_HUB_IMAGE__ found but DOCKER_HUB_USERNAME is empty"
  fi
fi

# ================================
# Validate docker-compose
# ================================
$DOCKER compose -f docker-compose.yml config

# ================================
# Cleanup
# ================================
$DOCKER compose down --remove-orphans
$DOCKER system prune -af
rm -f "$OUT_FILE" || true

# ================================
# Start all app replicas + nginx
# ================================
$DOCKER compose up -d express-app-admin-1 express-app-admin-2 express-app-admin-3 nginx

# ================================
# Wait for all app containers to be healthy
# ================================
for service in express-app-admin-1 express-app-admin-2 express-app-admin-3; do
    echo "Waiting for $service to be healthy..."
    $DOCKER wait "$service" >/dev/null
done

# ================================
# Generate node_upstream dynamically using service names
# ================================
TMP_FILE="$OUT_FILE.tmp"
{
  echo "upstream node_upstream {"
  echo "    least_conn;"
  for service in express-app-admin-1 express-app-admin-2 express-app-admin-3; do
    echo "    server ${service}:${APP_PORT} max_fails=3 fail_timeout=5s;"
  done
  echo "    keepalive 64;"
  echo "}"
} >"$TMP_FILE"
mv -f "$TMP_FILE" "$OUT_FILE"

# ================================
# Validate Nginx config
# ================================
$DCOMPOSE exec -T nginx nginx -t || echo "::warning::Nginx config test failed"

# ================================
# Reload Nginx safely
# ================================
$DCOMPOSE exec -T nginx nginx -s reload || echo "⚠ Nginx reload failed"

# ================================
# Health check
# ================================
curl -fsS -m 5 http://127.0.0.1/health || echo "::warning::/health not responding"

echo "Deployment complete ✅"
echo "Rendered upstreams:"
cat "$OUT_FILE"


