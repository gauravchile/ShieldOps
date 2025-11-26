# ---------- Stage 1: Build (Vite + Node.js) ----------
FROM node:20-alpine AS builder
WORKDIR /app

# Copy dependencies first for better caching
COPY package*.json ./
COPY .env ./

# Install all deps (no lockfile available)
RUN npm install --no-audit --legacy-peer-deps

# Copy remaining source
COPY . .

# Build arguments & environment
ARG VITE_API_BASE_URL=/api
ENV VITE_API_BASE_URL=${VITE_API_BASE_URL}

RUN echo "🌐 Building ShieldOps UI with API base: ${VITE_API_BASE_URL}" && \
    npm run build

# ---------- Stage 2: NGINX Runtime ----------
FROM nginx:stable-alpine

# Copy NGINX configs
COPY nginx.conf /etc/nginx/nginx.conf
COPY default.conf.template /etc/nginx/templates/default.conf.template

# Copy build output
COPY --from=builder /app/dist /usr/share/nginx/html

# Fix permissions before dropping privileges
RUN mkdir -p /var/cache/nginx /var/run /etc/nginx/conf.d && \
    chmod -R 777 /var/cache/nginx /var/run /etc/nginx/conf.d && \
    chown -R nginx:nginx /usr/share/nginx/html && \
    chmod -R 755 /usr/share/nginx/html && \
    echo "✅ NGINX permissions fixed & static files ready"

USER nginx
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
