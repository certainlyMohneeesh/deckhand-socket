#!/bin/bash

# Build and run DeckHand Socket.io server in Docker

set -e

echo "🐳 Building Docker image..."
docker build -t deckhand-socket:latest .

echo ""
echo "✅ Build complete!"
echo ""
echo "🚀 Starting container..."
docker run -d \
  -p 3001:3001 \
  -e PORT=3001 \
  -e CORS_ORIGIN="*" \
  --name deckhand-socket \
  --restart unless-stopped \
  deckhand-socket:latest

echo ""
echo "✅ Container started!"
echo ""
echo "📊 Container status:"
docker ps | grep deckhand-socket

echo ""
echo "🔍 Testing health endpoint..."
sleep 2
curl -s http://localhost:3001/health | jq '.' || curl -s http://localhost:3001/health

echo ""
echo ""
echo "✅ Socket.io server is running!"
echo ""
echo "📍 Endpoints:"
echo "   Health: http://localhost:3001/health"
echo "   Socket: http://localhost:3001"
echo ""
echo "📋 Useful commands:"
echo "   View logs:    docker logs -f deckhand-socket"
echo "   Stop server:  docker stop deckhand-socket"
echo "   Start server: docker start deckhand-socket"
echo "   Remove:       docker rm -f deckhand-socket"
echo ""
