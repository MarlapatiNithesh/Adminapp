# ---- Production runtime image ----
FROM node:20-slim

# Prevent zombie processes
RUN apt-get update && apt-get install -y --no-install-recommends tini curl \
  && rm -rf /var/lib/apt/lists/*

ENV NODE_ENV=production \
    PORT=5000 \
    GOOGLE_APPLICATION_CREDENTIALS="/app/serviceAccountKey.json"

WORKDIR /app

# Install only production deps
COPY package*.json ./
RUN npm ci --omit=dev

# Copy source (routes, server.js, etc.)
COPY . .

# ✅ Copy service account key
COPY serviceAccountKey.json ./serviceAccountKey.json

# ✅ Fix permissions so non-root "node" user can read it
RUN chown node:node /app/serviceAccountKey.json

EXPOSE 5000

# Healthcheck (expects your app has GET /health returning 200)
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD curl -fsS http://localhost:${PORT}/health || exit 1

# Drop root privileges
USER node

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["npm", "start"]


