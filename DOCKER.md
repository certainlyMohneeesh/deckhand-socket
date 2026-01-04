# 🐳 Docker Containerization Guide

Complete guide to containerize and deploy the DeckHand Socket.io server using Docker.

---

## 📦 Quick Start

### Build the Docker Image

```bash
cd socket-server

# Build the image
docker build -t deckhand-socket:latest .

# Or with a specific tag
docker build -t deckhand-socket:1.0.0 .
```

### Run the Container

```bash
# Simple run
docker run -p 3001:3001 deckhand-socket:latest

# Run with custom port
docker run -p 8080:3001 -e PORT=3001 deckhand-socket:latest

# Run in detached mode (background)
docker run -d -p 3001:3001 --name deckhand-socket deckhand-socket:latest

# Run with custom CORS
docker run -d -p 3001:3001 \
  -e CORS_ORIGIN="https://your-app.vercel.app" \
  --name deckhand-socket \
  deckhand-socket:latest
```

### Test the Container

```bash
# Check if running
docker ps

# View logs
docker logs deckhand-socket

# Follow logs (live)
docker logs -f deckhand-socket

# Test health endpoint
curl http://localhost:3001/health
```

---

## 🚀 Using Docker Compose (Recommended)

Docker Compose makes it easier to manage the container.

### Start the Server

```bash
# Build and start
docker-compose up --build

# Run in background
docker-compose up -d

# View logs
docker-compose logs -f
```

### Stop the Server

```bash
# Stop containers
docker-compose down

# Stop and remove volumes
docker-compose down -v
```

### Update and Restart

```bash
# Rebuild after code changes
docker-compose up --build -d

# Restart without rebuilding
docker-compose restart
```

---

## 🏗️ Dockerfile Explanation

```dockerfile
FROM oven/bun:1 as base
WORKDIR /app

# Install dependencies
COPY package.json bun.lockb ./
RUN bun install --frozen-lockfile

# Copy application code
COPY . .

# Expose Socket.io port
EXPOSE 3001

# Start the server
CMD ["bun", "run", "server.ts"]
```

**What it does**:
- Uses Bun's official Docker image (faster than Node.js)
- Installs dependencies with frozen lockfile
- Copies application code
- Exposes port 3001
- Runs the server with Bun

---

## 📤 Push to Docker Hub

### 1. Login to Docker Hub

```bash
docker login
# Enter your Docker Hub username and password
```

### 2. Tag the Image

```bash
# Format: docker tag IMAGE_NAME USERNAME/REPOSITORY:TAG
docker tag deckhand-socket:latest yourusername/deckhand-socket:latest
docker tag deckhand-socket:latest yourusername/deckhand-socket:1.0.0
```

### 3. Push to Docker Hub

```bash
docker push yourusername/deckhand-socket:latest
docker push yourusername/deckhand-socket:1.0.0
```

### 4. Pull and Run from Docker Hub

```bash
# Anyone can now pull and run your image
docker pull yourusername/deckhand-socket:latest
docker run -p 3001:3001 yourusername/deckhand-socket:latest
```

---

## ☁️ Deploy to Cloud Platforms

### Railway

Railway auto-detects the Dockerfile.

```bash
cd socket-server
railway login
railway init
railway up
```

**Or via GitHub**:
1. Push to GitHub
2. Connect repository in Railway
3. Railway auto-builds from Dockerfile
4. Get your URL: `https://deckhand-socket-production.up.railway.app`

### Render.com

1. Go to https://render.com/dashboard
2. New → Web Service
3. Connect your GitHub repo
4. **Docker settings**:
   - Environment: Docker
   - Root Directory: `socket-server`
   - Docker Command: (leave empty, uses CMD from Dockerfile)
5. Add environment variables:
   - `PORT`: Leave empty (Render provides)
   - `CORS_ORIGIN`: Your Vercel URL
6. Deploy!

### Fly.io

```bash
cd socket-server

# Login
fly auth login

# Launch (creates fly.toml if needed)
fly launch --image deckhand-socket:latest

# Or build on Fly's servers
fly deploy
```

### Google Cloud Run

```bash
# Build and push to Google Container Registry
gcloud builds submit --tag gcr.io/YOUR_PROJECT_ID/deckhand-socket

# Deploy
gcloud run deploy deckhand-socket \
  --image gcr.io/YOUR_PROJECT_ID/deckhand-socket \
  --platform managed \
  --region asia-south1 \
  --allow-unauthenticated \
  --port 3001
```

### AWS ECS (Elastic Container Service)

1. **Push to Amazon ECR**:
```bash
# Authenticate
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com

# Create repository
aws ecr create-repository --repository-name deckhand-socket

# Tag and push
docker tag deckhand-socket:latest YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/deckhand-socket:latest
docker push YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/deckhand-socket:latest
```

2. **Create ECS Task Definition** (use AWS Console or CLI)
3. **Deploy to ECS Cluster**

### Azure Container Instances

```bash
# Login
az login

# Create resource group
az group create --name deckhand-rg --location eastus

# Create container
az container create \
  --resource-group deckhand-rg \
  --name deckhand-socket \
  --image yourusername/deckhand-socket:latest \
  --ports 3001 \
  --dns-name-label deckhand-socket \
  --environment-variables PORT=3001 CORS_ORIGIN=*
```

---

## 🔧 Advanced Docker Usage

### Multi-Stage Build (Optimized)

For a smaller image, use multi-stage builds:

```dockerfile
# Build stage
FROM oven/bun:1 as builder
WORKDIR /app
COPY package.json bun.lockb ./
RUN bun install --frozen-lockfile --production
COPY . .

# Production stage
FROM oven/bun:1-slim
WORKDIR /app
COPY --from=builder /app .
EXPOSE 3001
CMD ["bun", "run", "server.ts"]
```

### With Health Checks

```dockerfile
FROM oven/bun:1 as base
WORKDIR /app

COPY package.json bun.lockb ./
RUN bun install --frozen-lockfile

COPY . .

EXPOSE 3001

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD bun run -e "fetch('http://localhost:3001/health').then(r => r.ok || process.exit(1))"

CMD ["bun", "run", "server.ts"]
```

### With Volume Mounts (for logs)

```bash
docker run -d \
  -p 3001:3001 \
  -v $(pwd)/logs:/app/logs \
  --name deckhand-socket \
  deckhand-socket:latest
```

---

## 🐙 Docker Commands Cheat Sheet

### Container Management

```bash
# List running containers
docker ps

# List all containers (including stopped)
docker ps -a

# Stop container
docker stop deckhand-socket

# Start container
docker start deckhand-socket

# Restart container
docker restart deckhand-socket

# Remove container
docker rm deckhand-socket

# Remove container (force)
docker rm -f deckhand-socket
```

### Image Management

```bash
# List images
docker images

# Remove image
docker rmi deckhand-socket:latest

# Remove all unused images
docker image prune

# Remove all images (careful!)
docker rmi $(docker images -q)
```

### Logs and Debugging

```bash
# View logs
docker logs deckhand-socket

# Follow logs
docker logs -f deckhand-socket

# Last 100 lines
docker logs --tail 100 deckhand-socket

# Execute command in running container
docker exec -it deckhand-socket sh

# Inspect container
docker inspect deckhand-socket

# Container stats (CPU, memory)
docker stats deckhand-socket
```

---

## 🌐 Environment Variables

Set via `-e` flag or docker-compose:

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `3001` | Server port |
| `CORS_ORIGIN` | `*` | Allowed origins (comma-separated) |

**Example**:
```bash
docker run -p 3001:3001 \
  -e PORT=3001 \
  -e CORS_ORIGIN="https://app.vercel.app,https://preview.vercel.app" \
  deckhand-socket:latest
```

---

## 📊 Monitoring in Production

### View Real-time Stats

```bash
docker stats deckhand-socket
```

### Set Resource Limits

```bash
docker run -d \
  -p 3001:3001 \
  --memory="512m" \
  --cpus="0.5" \
  --name deckhand-socket \
  deckhand-socket:latest
```

### Auto-restart Policy

```bash
docker run -d \
  -p 3001:3001 \
  --restart unless-stopped \
  --name deckhand-socket \
  deckhand-socket:latest
```

Restart policies:
- `no`: Don't restart (default)
- `always`: Always restart
- `unless-stopped`: Restart unless manually stopped
- `on-failure`: Only restart on error

---

## 🧪 Testing the Container

### Health Check

```bash
# Should return: {"status":"ok","connections":0}
curl http://localhost:3001/health
```

### Connection Test

```bash
# Using curl with Socket.io polling
curl "http://localhost:3001/socket.io/?EIO=4&transport=polling"
```

### Load Testing (with k6)

```javascript
// loadtest.js
import http from 'k6/http';
import { check } from 'k6';

export default function () {
  let res = http.get('http://localhost:3001/health');
  check(res, { 'status is 200': (r) => r.status === 200 });
}
```

Run: `k6 run --vus 10 --duration 30s loadtest.js`

---

## 🔒 Security Best Practices

### 1. Use Non-Root User

Add to Dockerfile:
```dockerfile
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser
```

### 2. Use .dockerignore

Already included:
```
node_modules
.git
.env
*.log
.DS_Store
```

### 3. Scan for Vulnerabilities

```bash
# Scan image
docker scan deckhand-socket:latest

# Or use Trivy
trivy image deckhand-socket:latest
```

### 4. Update Base Image Regularly

```bash
# Pull latest Bun image
docker pull oven/bun:1

# Rebuild
docker build -t deckhand-socket:latest .
```

---

## 🚨 Troubleshooting

### Container Won't Start

```bash
# Check logs
docker logs deckhand-socket

# Common issues:
# - Port already in use: Change -p 3002:3001
# - Missing dependencies: Rebuild image
# - Wrong CMD: Check Dockerfile
```

### Can't Connect to Container

```bash
# Check if port is exposed
docker port deckhand-socket

# Check if container is running
docker ps

# Test from inside container
docker exec -it deckhand-socket curl http://localhost:3001/health
```

### High Memory Usage

```bash
# Check stats
docker stats deckhand-socket

# Set memory limit
docker update --memory="512m" deckhand-socket
```

### Container Keeps Restarting

```bash
# Check logs for errors
docker logs deckhand-socket

# Remove restart policy temporarily
docker update --restart=no deckhand-socket
```

---

## 📚 Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Bun Docker Images](https://hub.docker.com/r/oven/bun)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)
- [Docker Hub](https://hub.docker.com/)

---

## ✅ Production Checklist

- [ ] Dockerfile builds successfully
- [ ] Image tagged with version
- [ ] Container runs and exposes port 3001
- [ ] Health check endpoint works
- [ ] Environment variables configured
- [ ] Pushed to container registry
- [ ] Deployed to cloud platform
- [ ] CORS configured correctly
- [ ] Monitoring/logging set up
- [ ] Resource limits configured
- [ ] Restart policy set
- [ ] Security scan passed

---

**Your socket server is now containerized and ready for production!** 🎉
