#!/usr/bin/env bash
# Setup systemd service for socket server on DigitalOcean
# Run this on the droplet as root

set -euo pipefail

echo "Setting up systemd service for DeckHand Socket Server"
echo "======================================================"
echo ""

if [ "$EUID" -ne 0 ]; then 
   echo "❌ Please run as root (sudo)"
   exit 1
fi

# Detect user
DEPLOY_USER=${1:-deckhand}

echo "Creating systemd service for user: $DEPLOY_USER"

# Get Bun path for the user
BUN_PATH=$(sudo -u "$DEPLOY_USER" bash -c 'echo $HOME/.bun/bin/bun')

cat > /etc/systemd/system/deckhand-socket.service << EOF
[Unit]
Description=DeckHand Socket.io Server
After=network.target

[Service]
Type=simple
User=$DEPLOY_USER
WorkingDirectory=/home/$DEPLOY_USER/socket-server
ExecStart=$BUN_PATH run server.ts
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

Environment="NODE_ENV=production"
Environment="PORT=3001"

[Install]
WantedBy=multi-user.target
EOF

echo "✅ Service file created"

# Reload systemd
systemctl daemon-reload
echo "✅ Systemd reloaded"

# Enable on boot
systemctl enable deckhand-socket.service
echo "✅ Service enabled on boot"

# Start service
systemctl start deckhand-socket.service
echo "✅ Service started"

# Check status
sleep 1
systemctl status deckhand-socket.service

echo ""
echo "📋 Service management commands:"
echo "  sudo systemctl start deckhand-socket.service     # Start"
echo "  sudo systemctl stop deckhand-socket.service      # Stop"
echo "  sudo systemctl restart deckhand-socket.service   # Restart"
echo "  sudo systemctl status deckhand-socket.service    # Status"
echo "  sudo journalctl -u deckhand-socket.service -f    # Live logs"
echo ""
echo "✅ Setup complete!"
