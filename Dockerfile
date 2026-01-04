FROM oven/bun:1 AS base
WORKDIR /app

# Install dependencies
COPY package.json bun.lock ./
RUN bun install --frozen-lockfile

# Copy application code
COPY . .

# Expose Socket.io port
EXPOSE 3001

# Start the server
CMD ["bun", "run", "server.ts"]
