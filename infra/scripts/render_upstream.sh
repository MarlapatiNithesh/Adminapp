#!/usr/bin/env bash
set -euo pipefail

# --- Config (tweak if your names change) ---
APP_DIR="/opt/app"
OUT_FILE="$APP_DIR/nginx/conf.d/upstreams.generated.conf"
SERVICE_PREFIX="express-app-admin"     # matches express-app-admin-1/2/3
NETWORK_NAME="${NETWORK_NAME:-app-net}"
APP_PORT="${APP_PORT:-5000}"

# Use sudo docker consistently (matches your CD workflow)
DOCKER="sudo docker"
DCOMPOSE="sudo docker compose -f $APP_DIR/docker-compose.yml"

# --- Discover container IPs on the intended network ---
# We select containers whose names start with SERVICE_PREFIX-
mapfile -t CID_NAME <<<"$($DOCKER ps --format '{{.ID}} {{.Names}}' | awk -v p="$SERVICE_PREFIX" '$2 ~ "^"p"-" {print $0}')"

IPS=()
for row in "${CID_NAME[@]}"; do
  cid="${row%% *}"
  # extract IP specific to NETWORK_NAME; fall back to first network if not present
  ip="$($DOCKER inspect -f "{{ with index .NetworkSettings.Networks \"$NETWORK_NAME\" }}{{ .IPAddress }}{{ end }}" "$cid")"
  if [[ -z "$ip" ]]; then
    ip="$($DOCKER inspect -f '{{ range .NetworkSettings.Networks }}{{ .IPAddress }}{{ end }}' "$cid")"
  fi
  [[ -n "$ip" ]] && IPS+=("$ip")
done

# De-dup & sort
if ((${#IPS[@]})); then
  mapfile -t IPS < <(printf "%s\n" "${IPS[@]}" | sort -u)
fi

# --- Render upstream to a temp file then move atomically ---
TMP_FILE="$OUT_FILE.tmp"
{
  echo "upstream app_upstream {"
  if ((${#IPS[@]})); then
    for ip in "${IPS[@]}"; do
      echo "  server ${ip}:${APP_PORT} max_fails=3 fail_timeout=5s;"
    done
  else
    # Failsafe: point to a blackhole so nginx config still validates
    echo "  server 127.0.0.1:9 down;"
  fi
  echo "  keepalive 64;"
  echo "}"
} >"$TMP_FILE"

mv -f "$TMP_FILE" "$OUT_FILE"

# --- IMPORTANT: Do NOT edit app.conf here ---
# Your nginx.conf already has: include /etc/nginx/conf.d/*.conf;
# and app.conf is a read-only bind mount. Placing the generated file
# in conf.d/ is enough for nginx to load it.

# --- Test & reload nginx cleanly ---
$DCOMPOSE exec -T nginx nginx -t
$DCOMPOSE exec -T nginx nginx -s reload || true

echo "Rendered upstreams to $OUT_FILE:"
cat "$OUT_FILE"

