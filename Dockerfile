# ─────────────────────────────────────────────
# Stage 1: Build frontend
# ─────────────────────────────────────────────
FROM node:20-alpine AS frontend-builder

WORKDIR /app/frontend
COPY frontend/package*.json ./
RUN npm ci --silent
COPY frontend/ ./
RUN npm run build

# ─────────────────────────────────────────────
# Stage 2: Build backend
# ─────────────────────────────────────────────
FROM node:20-alpine AS backend-builder

WORKDIR /app/backend
COPY backend/package*.json ./
RUN npm ci --silent
COPY backend/ ./
RUN npx tsc

# ─────────────────────────────────────────────
# Stage 3: Production image
# ─────────────────────────────────────────────
FROM node:20-alpine AS production

ENV NODE_ENV=production
WORKDIR /app

# Backend production deps only
COPY backend/package*.json ./
RUN npm ci --only=production --silent

# Compiled backend
COPY --from=backend-builder /app/backend/dist ./dist

# Built frontend (served as static files by Express)
COPY --from=frontend-builder /app/frontend/dist ./frontend/dist

EXPOSE 3001

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:3001/health || exit 1

CMD ["node", "dist/index.js"]
