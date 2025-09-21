#!/bin/bash

# Cloudflare Tunnel Setup for iOS API Backend
# This script sets up a Cloudflare tunnel for api.timrattigan.com

set -e

echo "================================================"
echo "Cloudflare Tunnel Setup for iOS API Backend"
echo "================================================"
echo

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -eq 0 ]; then
   echo -e "${RED}Please do not run as root${NC}"
   exit 1
fi

# Step 1: Install cloudflared if not present
if [ ! -f ~/cloudflared ]; then
    echo -e "${YELLOW}Step 1: Downloading cloudflared...${NC}"
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O ~/cloudflared
    chmod +x ~/cloudflared
    echo -e "${GREEN}✓ cloudflared downloaded${NC}"
else
    echo -e "${GREEN}✓ cloudflared already installed${NC}"
fi

# Step 2: Check if already authenticated
if [ ! -d ~/.cloudflared ]; then
    mkdir -p ~/.cloudflared
fi

if [ ! -f ~/.cloudflared/cert.pem ]; then
    echo -e "${YELLOW}Step 2: Authenticating with Cloudflare...${NC}"
    echo "This will open a browser window. Please log in to your Cloudflare account."
    echo "Press Enter to continue..."
    read
    ~/cloudflared tunnel login
    echo -e "${GREEN}✓ Authenticated with Cloudflare${NC}"
else
    echo -e "${GREEN}✓ Already authenticated with Cloudflare${NC}"
fi

# Step 3: Create tunnel for API
echo -e "${YELLOW}Step 3: Creating API tunnel...${NC}"
TUNNEL_NAME="ios-api-tunnel"

# Check if tunnel already exists
if ~/cloudflared tunnel list | grep -q $TUNNEL_NAME; then
    echo -e "${YELLOW}Tunnel '$TUNNEL_NAME' already exists${NC}"
    TUNNEL_ID=$(~/cloudflared tunnel list | grep $TUNNEL_NAME | awk '{print $1}')
else
    ~/cloudflared tunnel create $TUNNEL_NAME
    TUNNEL_ID=$(~/cloudflared tunnel list | grep $TUNNEL_NAME | awk '{print $1}')
    echo -e "${GREEN}✓ Tunnel created with ID: $TUNNEL_ID${NC}"
fi

# Step 4: Create tunnel configuration
echo -e "${YELLOW}Step 4: Creating tunnel configuration...${NC}"

cat > ~/.cloudflared/config.yml << EOF
tunnel: $TUNNEL_ID
credentials-file: /home/$USER/.cloudflared/$TUNNEL_ID.json

ingress:
  # API endpoint
  - hostname: api.timrattigan.com
    service: http://localhost:3000
    originRequest:
      noTLSVerify: true
      connectTimeout: 30s
      # WebSocket support
      httpHostHeader: api.timrattigan.com
      originServerName: api.timrattigan.com

  # Health check endpoint (can be accessed directly)
  - hostname: health.api.timrattigan.com
    service: http://localhost:3000/api/health
    originRequest:
      noTLSVerify: true

  # WebSocket endpoint (if on different port)
  - hostname: ws.api.timrattigan.com
    service: ws://localhost:3001
    originRequest:
      noTLSVerify: true

  # Catch-all
  - service: http_status:404
EOF

echo -e "${GREEN}✓ Configuration created${NC}"

# Step 5: Setup DNS routing
echo -e "${YELLOW}Step 5: Setting up DNS routing...${NC}"

# Route api.timrattigan.com
echo "Creating DNS route for api.timrattigan.com..."
~/cloudflared tunnel route dns $TUNNEL_NAME api.timrattigan.com 2>/dev/null || \
    echo "DNS route for api.timrattigan.com might already exist"

# Route health subdomain
echo "Creating DNS route for health.api.timrattigan.com..."
~/cloudflared tunnel route dns $TUNNEL_NAME health.api.timrattigan.com 2>/dev/null || \
    echo "DNS route for health.api.timrattigan.com might already exist"

# Route WebSocket subdomain
echo "Creating DNS route for ws.api.timrattigan.com..."
~/cloudflared tunnel route dns $TUNNEL_NAME ws.api.timrattigan.com 2>/dev/null || \
    echo "DNS route for ws.api.timrattigan.com might already exist"

echo -e "${GREEN}✓ DNS routing configured${NC}"

# Step 6: Create systemd service
echo -e "${YELLOW}Step 6: Creating systemd service...${NC}"

sudo tee /etc/systemd/system/cloudflared-api.service > /dev/null << EOF
[Unit]
Description=Cloudflare Tunnel for iOS API
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$USER
ExecStart=/home/$USER/cloudflared tunnel run
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=cloudflared-api

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable service
sudo systemctl daemon-reload
sudo systemctl enable cloudflared-api.service
echo -e "${GREEN}✓ Systemd service created and enabled${NC}"

# Step 7: Create test script
echo -e "${YELLOW}Step 7: Creating test script...${NC}"

cat > ~/ios_ubuntu_api_project/scripts/test_tunnel.sh << 'TESTSCRIPT'
#!/bin/bash

echo "Testing Cloudflare Tunnel Connection..."
echo

# Test API endpoint
echo -n "Testing api.timrattigan.com... "
if curl -s -f -o /dev/null -w "%{http_code}" https://api.timrattigan.com > /dev/null 2>&1; then
    echo "✓ Reachable"
else
    echo "✗ Not reachable (Is the API server running?)"
fi

# Test health endpoint
echo -n "Testing health.api.timrattigan.com... "
if curl -s -f -o /dev/null -w "%{http_code}" https://health.api.timrattigan.com > /dev/null 2>&1; then
    echo "✓ Reachable"
else
    echo "✗ Not reachable"
fi

echo
echo "Note: These will only work after starting the API server on port 3000"
TESTSCRIPT

chmod +x ~/ios_ubuntu_api_project/scripts/test_tunnel.sh
echo -e "${GREEN}✓ Test script created${NC}"

# Final instructions
echo
echo "================================================"
echo -e "${GREEN}Cloudflare Tunnel Setup Complete!${NC}"
echo "================================================"
echo
echo -e "${YELLOW}Next Steps:${NC}"
echo
echo "1. Start the tunnel manually (for testing):"
echo "   ~/cloudflared tunnel run"
echo
echo "2. Or start as a service:"
echo "   sudo systemctl start cloudflared-api"
echo
echo "3. Check tunnel status:"
echo "   sudo systemctl status cloudflared-api"
echo
echo "4. View tunnel logs:"
echo "   sudo journalctl -u cloudflared-api -f"
echo
echo "5. Test connectivity (after starting API server):"
echo "   ~/ios_ubuntu_api_project/scripts/test_tunnel.sh"
echo
echo -e "${YELLOW}Important URLs:${NC}"
echo "• API Endpoint: https://api.timrattigan.com"
echo "• Health Check: https://health.api.timrattigan.com"
echo "• WebSocket: wss://ws.api.timrattigan.com"
echo
echo -e "${GREEN}The tunnel is ready! Now set up your API server on port 3000.${NC}"