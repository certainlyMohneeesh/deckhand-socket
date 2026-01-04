#!/bin/bash

# Stop and remove DeckHand Socket.io server container

set -e

echo "🛑 Stopping container..."
docker stop deckhand-socket 2>/dev/null || echo "Container not running"

echo "🗑️  Removing container..."
docker rm deckhand-socket 2>/dev/null || echo "Container already removed"

echo ""
echo "✅ Container stopped and removed"
echo ""
echo "To rebuild and run:"
echo "  ./docker-run.sh"
echo ""
echo "To remove image:"
echo "  docker rmi deckhand-socket:latest"
echo ""
