#!/usr/bin/env bash
# Setup script for DigitalOcean droplet
# Run this after SSHing into your droplet as root or with sudo

set -euo pipefail

echo "🚀 DeckHand Socket Server Setup Script"
echo "========================================"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
   log_error "Please run as root (sudo)"
   exit 1
fi

# Step 1: Update system
log_info "Updating system packages..."
apt update && apt upgrade -y
apt install -y curl wget git build-essential nginx certbot python3-certbot-nginx

# Step 2: Create non-root user
log_info "Creating deckhand user..."
if id -u deckhand > /dev/null 2>&1; then
    log_warn "User 'deckhand' already exists, skipping user creation"
else
    adduser --disabled-password --gecos "DeckHand Service" deckhand
    usermod -aG sudo deckhand
    log_info "User 'deckhand' created"
fi

# Step 3: Install Bun for deckhand user
log_info "Installing Bun for deckhand user..."
sudo -u deckhand bash -c 'curl -fsSL https://bun.sh/install | bash'
sudo -u deckhand bash -c 'echo "export BUN_INSTALL=\"\$HOME/.bun\"" >> ~/.bashrc'
sudo -u deckhand bash -c 'echo "export PATH=\"\$BUN_INSTALL/bin:\$PATH\"" >> ~/.bashrc'

# Step 4: Setup directories
log_info "Setting up directories..."
mkdir -p /home/deckhand/socket-server
chown -R deckhand:deckhand /home/deckhand/socket-server

# Step 5: Create systemd service file
log_info "Creating systemd service..."
cat > /etc/systemd/system/deckhand-socket.service << 'EOF'
[Unit]
Description=DeckHand Socket.io Server
After=network.target

[Service]
Type=simple
User=deckhand
WorkingDirectory=/home/deckhand/socket-server
ExecStart=/home/deckhand/.bun/bin/bun run server.ts
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

Environment="NODE_ENV=production"
Environment="PORT=3001"

[Install]
WantedBy=multi-user.target
EOF

log_info "Systemd service created"

# Step 6: Enable Nginx
log_info "Enabling Nginx..."
systemctl enable nginx
systemctl start nginx

# Step 7: Setup firewall (UFW)
log_info "Setting up firewall..."
ufw --force enable
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw status

echo ""
echo "========================================"
echo -e "${GREEN}✅ Setup Complete!${NC}"
echo "========================================"
echo ""
echo "📋 Next steps:"
echo "1. Upload socket-server files to /home/deckhand/socket-server/"
echo "   scp -r ./socket-server deckhand@YOUR_IP:/home/deckhand/"
echo ""
echo "2. Install dependencies:"
echo "   ssh deckhand@YOUR_IP"
echo "   cd ~/socket-server && /home/deckhand/.bun/bin/bun install"
echo ""
echo "3. Configure Nginx (optional, with SSL):"
echo "   See DIGITALOCEAN_DEPLOYMENT.md Step 5"
echo ""
echo "4. Start the service:"
echo "   sudo systemctl start deckhand-socket.service"
echo "   sudo systemctl status deckhand-socket.service"
echo ""
echo "5. Test health endpoint:"
echo "   curl http://YOUR_IP:3001/health"
echo ""
