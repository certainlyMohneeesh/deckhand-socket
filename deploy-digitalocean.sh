#!/usr/bin/env bash
# Deploy socket-server to DigitalOcean droplet
# Usage: ./deploy-digitalocean.sh <DROPLET_IP> <USER>
# Example: ./deploy-digitalocean.sh 143.198.123.45 deckhand

set -euo pipefail

if [ $# -lt 2 ]; then
    echo "Usage: $0 <DROPLET_IP> <USER>"
    echo "Example: $0 143.198.123.45 deckhand"
    exit 1
fi

DROPLET_IP=$1
DEPLOY_USER=${2:-deckhand}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 Deploying Socket Server to DigitalOcean"
echo "=========================================="
echo "Droplet IP: $DROPLET_IP"
echo "User: $DEPLOY_USER"
echo "Local Path: $SCRIPT_DIR"
echo ""

# Test SSH connection
echo "Testing SSH connection..."
if ! ssh -q -o ConnectTimeout=5 "$DEPLOY_USER@$DROPLET_IP" exit; then
    echo "❌ Cannot connect to $DEPLOY_USER@$DROPLET_IP"
    echo "Please check your IP and credentials"
    exit 1
fi
echo "✅ SSH connection successful"
echo ""

# Create remote directories
echo "Creating remote directories..."
ssh "$DEPLOY_USER@$DROPLET_IP" "mkdir -p ~/socket-server && echo '✅ Directories created'"

# Copy files
echo "Copying socket-server files..."
scp -r "$SCRIPT_DIR"/* "$DEPLOY_USER@$DROPLET_IP:~/socket-server/" || {
    echo "⚠️  Some files may have been skipped (e.g., node_modules)"
    echo "This is okay - dependencies will be installed on the droplet"
}
echo "✅ Files copied"
echo ""

# Install dependencies
echo "Installing dependencies on droplet..."
ssh "$DEPLOY_USER@$DROPLET_IP" << 'DEPLOY_SCRIPT'
    echo "Installing Bun dependencies..."
    cd ~/socket-server
    
    # Ensure Bun is in PATH
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
    
    # Install
    bun install --frozen-lockfile || bun install
    
    echo "✅ Dependencies installed"
    
    # Verify server.ts exists
    if [ -f "server.ts" ]; then
        echo "✅ server.ts found"
    else
        echo "❌ server.ts not found!"
        exit 1
    fi
DEPLOY_SCRIPT

echo ""
echo "=========================================="
echo "✅ Deployment Complete!"
echo "=========================================="
echo ""
echo "📋 Next steps:"
echo "1. Setup systemd service (as root):"
echo "   ssh root@$DROPLET_IP"
echo "   bash /home/$DEPLOY_USER/socket-server/setup-service.sh"
echo ""
echo "2. Or manually start the service:"
echo "   ssh $DEPLOY_USER@$DROPLET_IP"
echo "   cd ~/socket-server && /home/$DEPLOY_USER/.bun/bin/bun run server.ts"
echo ""
echo "3. Test health endpoint:"
echo "   curl http://$DROPLET_IP:3001/health"
echo ""
echo "4. Setup Nginx with SSL (optional):"
echo "   See DIGITALOCEAN_DEPLOYMENT.md Step 5"
echo ""
