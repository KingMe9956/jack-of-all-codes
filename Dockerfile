# JACK v2.0 - Hardened Docker Container
# Multi-stage build for minimal attack surface

# Stage 1: Build environment
FROM node:18-alpine AS builder

# Install build dependencies
RUN apk add --no-cache \
    git \
    python3 \
    make \
    g++

WORKDIR /build

# Copy package files
COPY package*.json ./

# Install dependencies (with audit)
RUN npm ci --only=production && \
    npm audit fix && \
    npm cache clean --force

# Stage 2: Security scanning tools
FROM alpine:3.18 AS security-tools

RUN apk add --no-cache \
    clamav \
    clamav-libunrar \
    freshclam

# Update virus definitions
RUN freshclam || true

# Stage 3: Production runtime
FROM node:18-alpine

# Create non-root user
RUN addgroup -g 1000 jack && \
    adduser -D -u 1000 -G jack jack

# Install runtime dependencies
RUN apk add --no-cache \
    git \
    docker-cli \
    openssl \
    ca-certificates \
    tini

# Copy ClamAV from security tools stage
COPY --from=security-tools /usr/bin/clamscan /usr/bin/clamscan
COPY --from=security-tools /usr/bin/freshclam /usr/bin/freshclam
COPY --from=security-tools /usr/lib/libclamav* /usr/lib/
COPY --from=security-tools /usr/share/clamav /usr/share/clamav

# Copy node_modules from builder
COPY --from=builder /build/node_modules /app/node_modules

# Set working directory
WORKDIR /app

# Copy application code
COPY --chown=jack:jack . .

# Create necessary directories with proper permissions
RUN mkdir -p /var/log/jack /var/quarantine/jack /tmp/jack-builds && \
    chown -R jack:jack /var/log/jack /var/quarantine/jack /tmp/jack-builds && \
    chmod 750 /var/log/jack /var/quarantine/jack /tmp/jack-builds

# Security hardening
RUN chmod -R 550 /app && \
    chmod 500 /app/jack-v2-hardened.js

# Switch to non-root user
USER jack

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD node -e "require('./jack-v2-hardened.js')"

# Use tini to handle signals properly
ENTRYPOINT ["/sbin/tini", "--"]

# Start Jack
CMD ["node", "jack-v2-hardened.js"]

# Labels
LABEL maintainer="Jack-of-All-Codes" \
      version="2.0" \
      description="Hardened AI Development Agent with Enterprise Security" \
      security.level="production"
# Labels
LABEL maintainer="Jack AI Agent" \
      version="2.0" \
      description="Hardened AI Development Agent with Enterprise Security" \
      security.level="production"
