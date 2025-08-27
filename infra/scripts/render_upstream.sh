#!/usr/bin/env bash
set -euo pipefail

# --- Config ---
APP_DIR="/opt/app"
OUT_FILE="$APP_DIR/nginx/conf.d/upstreams.generated.conf"
SERVICE_PREFIX="express-app-admin"     # matches express-app-admin-1/2/3
NETWORK_NAME="${NETWORK_NAME:-app-net}"
APP_PORT="${APP_PORT:-5000}"

DOCKER="sudo docker"
DCOMPOSE="sudo docker compose -f $APP_DIR/docker-compose.yml"

# --- Ensure old file is removed before generating ---
rm -f "$OUT_FILE"

# --- Discover container IPs on the intended network ---
mapfile -t CID_NAME <<<"$($DOCKER ps --format '{{.ID}} {{.Names}}' | awk -v p="$SERVICE_PREFIX" '$2 ~ "^"p"-" {print $0}')"

IPS=()
for row in "${CID_NAME[@]}"; do
  cid="${row%% *}"
  ip="$($DOCKER inspect -f "{{ with index .NetworkSettings.Networks \"$NETWORK_NAME\" }}{{ .IPAddress }}{{ end }}" "$cid")"
  [[ -z "$ip" ]] && ip="$($DOCKER inspect -f '{{ range .NetworkSettings.Networks }}{{ .IPAddress }}{{ end }}' "$cid")"
  [[ -n "$ip" ]] && IPS+=("$ip")
done

# Deduplicate & sort IPs
if ((${#IPS[@]})); then
  mapfile -t IPS < <(printf "%s\n" "${IPS[@]}" | sort -u)
fi

# --- Render upstreams to a temp file then move atomically ---
TMP_FILE="$OUT_FILE.tmp"
{
  echo "upstream app_upstream {"
  if ((${#IPS[@]})); then
    for ip in "${IPS[@]}"; do
      echo "  server ${ip}:${APP_PORT} max_fails=3 fail_timeout=5s;"
    done
  else
    # fallback so nginx config still validates
    echo "  server 127.0.0.1:9 down;"
  fi
  echo "  keepalive 64;"
  echo "}"
} >"$TMP_FILE"

# Atomically move into place
mv -f "$TMP_FILE" "$OUT_FILE"

# --- Test nginx configuration and reload safely ---
$DCOMPOSE exec -T nginx nginx -t
$DCOMPOSE exec -T nginx nginx -s reload || echo "⚠ Nginx reload failed (check for duplicates)"

echo "Rendered upstreams to $OUT_FILE:"
cat "$OUT_FILE"

