# ---------- Stage 1: Node.js Backend ----------
FROM node:20-alpine
WORKDIR /app

# Copy dependency manifests and install
COPY package*.json ./
RUN npm install --omit=dev --no-audit

# Copy source code and supporting files
COPY src ./src
COPY users.json ./users.json

# Set environment and expose port
ENV NODE_ENV=production
EXPOSE 8081

# Run backend
CMD ["node", "src/server.js"]
