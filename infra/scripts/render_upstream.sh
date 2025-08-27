#!/usr/bin/env bash
set -Eeuo pipefail
set -x

# --- Config ---
APP_DIR="/opt/app"
UPSTREAMS_DIR="$APP_DIR/nginx/conf.d/upstreams"
OUT_FILE="$UPSTREAMS_DIR/app_upstream.conf"
SERVICE_PREFIX="express-app-admin"     # matches express-app-admin-1/2/3
NETWORK_NAME="${NETWORK_NAME:-app-net}"
APP_PORT="${APP_PORT:-5000}"

DOCKER="sudo docker"
DCOMPOSE="sudo docker compose -f $APP_DIR/docker-compose.yml"

# --- Ensure necessary directories exist ---
mkdir -p "$UPSTREAMS_DIR"

# --- Sanity checks ---
cd "$APP_DIR"
[ -f docker-compose.yml ] || { echo "::error::docker-compose.yml missing"; exit 1; }
[ -f nginx/nginx.conf ] || { echo "::error::nginx/nginx.conf missing"; exit 1; }
[ -f nginx/conf.d/app.conf ] || { echo "::error::nginx/conf.d/app.conf missing"; exit 1; }

# --- Ensure Docker is installed and running ---
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker "$USER" || true
fi
sudo systemctl enable --now docker || true
sudo docker --version
sudo docker compose version || true

# --- Docker Hub login if private image ---
if [ -n "${DKR_USER:-}" ] && [ -n "${DKR_TOKEN:-}" ]; then
  echo "$DKR_TOKEN" | sudo docker login -u "$DKR_USER" --password-stdin
fi

# --- Replace placeholder image if exists ---
if grep -q "__DOCKER_HUB_IMAGE__" docker-compose.yml; then
  if [ -n "${DKR_USER:-}" ]; then
    sudo sed -i "s|__DOCKER_HUB_IMAGE__|$DKR_USER/admin-app:latest|g" docker-compose.yml
  else
    echo "::warning::__DOCKER_HUB_IMAGE__ found but DOCKER_HUB_USERNAME is empty"
  fi
fi

# --- Validate docker-compose ---
sudo docker compose -f docker-compose.yml config

# --- FULL CLEANUP to avoid duplicates ---
sudo docker compose down --remove-orphans
sudo docker system prune -af
sudo rm -f "$OUT_FILE" || true

# --- Start nginx + first app ---
sudo docker compose up -d nginx express-app-admin-1

# --- Render upstreams safely ---
mapfile -t CID_NAME <<<"$($DOCKER ps --filter "name=$SERVICE_PREFIX" --filter "status=running" --format '{{.ID}} {{.Names}}')"
IPS=()
for row in "${CID_NAME[@]}"; do
  cid="${row%% *}"
  ip="$($DOCKER inspect -f "{{ with index .NetworkSettings.Networks \"$NETWORK_NAME\" }}{{ .IPAddress }}{{ end }}" "$cid")"
  [[ -n "$ip" ]] && IPS+=("$ip")
done
if ((${#IPS[@]})); then
  mapfile -t IPS < <(printf "%s\n" "${IPS[@]}" | sort -u)
fi

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

# --- Validate Nginx configuration ---
$DCOMPOSE exec -T nginx nginx -t

# --- Start remaining replicas ---
sudo docker compose up -d express-app-admin-2 express-app-admin-3

# --- Reload nginx safely ---
$DCOMPOSE exec -T nginx nginx -s reload || echo "⚠ Nginx reload failed (check for duplicates)"

# --- Health check ---
curl -fsS -m 5 http://127.0.0.1/health || echo "::warning::/health not responding"

echo "Deployment complete ✅"
echo "Rendered upstreams:"
cat "$OUT_FILE"

