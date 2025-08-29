#!/usr/bin/env bash
set -Eeuo pipefail
set -x

# ================================
# Configuration
# ================================
APP_DIR="/opt/app"
UPSTREAMS_DIR="$APP_DIR/nginx/conf.d/upstreams"
OUT_FILE="$UPSTREAMS_DIR/app_upstream.conf"
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
# Start Nginx + first app
# ================================
$DOCKER compose up -d nginx "${SERVICE_PREFIX}-1"

# ================================
# Wait for app containers to be healthy and collect IPs
# ================================
echo "Waiting for containers to be healthy..."
RETRIES=12
SLEEP_SEC=5
IPS=()

for service in "${SERVICE_PREFIX}-1" "${SERVICE_PREFIX}-2" "${SERVICE_PREFIX}-3"; do
    echo "Checking $service..."
    for ((i=0; i<RETRIES; i++)); do
        STATUS=$($DOCKER inspect --format='{{.State.Health.Status}}' "$service" 2>/dev/null || echo "missing")
        if [[ "$STATUS" == "healthy" ]]; then
            ip=$($DOCKER inspect -f "{{ with index .NetworkSettings.Networks \"$NETWORK_NAME\" }}{{ .IPAddress }}{{ end }}" "$service")
            if [[ -n "$ip" ]]; then
                IPS+=("$ip")
                echo "  $service is healthy at $ip"
                break
            fi
        fi
        echo "  $service not ready yet ($i/$RETRIES). Waiting $SLEEP_SEC s..."
        sleep $SLEEP_SEC
    done
done

# Remove duplicates
if ((${#IPS[@]})); then
    mapfile -t IPS < <(printf "%s\n" "${IPS[@]}" | sort -u)
fi

# ================================
# Generate Nginx upstreams
# ================================
TMP_FILE="$OUT_FILE.tmp"
{
  echo "upstream app_upstream {"
  if ((${#IPS[@]})); then
    for ip in "${IPS[@]}"; do
      echo "  server ${ip}:${APP_PORT} max_fails=3 fail_timeout=5s;"
    done
  else
    echo "  server 127.0.0.1:9 down;"
  fi
  echo "  keepalive 64;"
  echo "}"
} >"$TMP_FILE"
mv -f "$TMP_FILE" "$OUT_FILE"

# ================================
# Validate Nginx config
# ================================
$DCOMPOSE exec -T nginx nginx -t || echo "::warning::Nginx config test failed"

# ================================
# Start remaining app replicas
# ================================
$DOCKER compose up -d "${SERVICE_PREFIX}-2" "${SERVICE_PREFIX}-3"

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

