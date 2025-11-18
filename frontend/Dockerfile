# Multi-stage Dockerfile for Svelte frontend

# Development stage
FROM cgr.dev/chainguard/node:latest AS development
WORKDIR /app

USER root
RUN npm install -g pnpm
USER node

# Copy package files
COPY --chown=node:node package.json pnpm-lock.yaml ./

# Install dependencies
RUN pnpm install

# Copy source code
COPY --chown=node:node . .

# Expose Vite dev server port
EXPOSE 5173

# Development command
CMD ["pnpm", "run", "dev"]

# Builder stage
FROM cgr.dev/chainguard/node:latest AS builder
WORKDIR /app

USER root
RUN npm install -g pnpm
USER node

# Copy package files
COPY --chown=node:node package.json pnpm-lock.yaml ./

# Install dependencies
RUN pnpm install --frozen-lockfile

# Copy source code
COPY --chown=node:node . .

# Build the application
RUN pnpm run build

# Production stage with Nginx
FROM cgr.dev/chainguard/nginx:latest
WORKDIR /usr/share/nginx/html

# Copy built assets from builder
COPY --from=builder --chown=nginx:nginx /app/dist .

# Copy custom nginx config
COPY --chown=nginx:nginx nginx.conf /etc/nginx/nginx.conf

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["wget", "--quiet", "--tries=1", "--spider", "http://localhost:8080/health"] || exit 1
