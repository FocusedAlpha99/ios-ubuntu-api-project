#!/bin/bash

# Setup script for API backend service with PM2

set -e

echo "================================================"
echo "API Backend Service Setup"
echo "================================================"
echo

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

PROJECT_DIR="/home/$USER/ios_ubuntu_api_project"
SERVER_DIR="$PROJECT_DIR/server"

# Step 1: Install Node.js if not present
echo -e "${YELLOW}Step 1: Checking Node.js installation...${NC}"
if ! command -v node &> /dev/null; then
    echo "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
else
    echo -e "${GREEN}✓ Node.js $(node -v) installed${NC}"
fi

# Step 2: Install PM2 globally
echo -e "${YELLOW}Step 2: Installing PM2 process manager...${NC}"
if ! command -v pm2 &> /dev/null; then
    sudo npm install -g pm2
    echo -e "${GREEN}✓ PM2 installed${NC}"
else
    echo -e "${GREEN}✓ PM2 already installed${NC}"
fi

# Step 3: Install dependencies
echo -e "${YELLOW}Step 3: Installing API dependencies...${NC}"
cd $SERVER_DIR

if [ ! -d "node_modules" ]; then
    npm install
    echo -e "${GREEN}✓ Dependencies installed${NC}"
else
    echo -e "${GREEN}✓ Dependencies already installed${NC}"
fi

# Step 4: Create .env file from example
echo -e "${YELLOW}Step 4: Setting up environment file...${NC}"
if [ ! -f "$SERVER_DIR/.env" ]; then
    cp "$SERVER_DIR/.env.example" "$SERVER_DIR/.env"

    # Generate a random JWT secret
    JWT_SECRET=$(openssl rand -hex 32)
    sed -i "s/your-super-secret-jwt-key-change-this-in-production/$JWT_SECRET/" "$SERVER_DIR/.env"

    echo -e "${GREEN}✓ .env file created with secure JWT secret${NC}"
else
    echo -e "${YELLOW}⚠ .env file already exists${NC}"
fi

# Step 5: Create PM2 ecosystem file
echo -e "${YELLOW}Step 5: Creating PM2 configuration...${NC}"
cat > "$PROJECT_DIR/ecosystem.config.js" << EOF
module.exports = {
  apps: [{
    name: 'ios-api',
    script: '$SERVER_DIR/app.js',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    error_file: '$PROJECT_DIR/logs/error.log',
    out_file: '$PROJECT_DIR/logs/out.log',
    log_file: '$PROJECT_DIR/logs/combined.log',
    time: true
  }]
}
EOF

echo -e "${GREEN}✓ PM2 configuration created${NC}"

# Step 6: Create logs directory
echo -e "${YELLOW}Step 6: Creating logs directory...${NC}"
mkdir -p "$PROJECT_DIR/logs"
echo -e "${GREEN}✓ Logs directory created${NC}"

# Step 7: Start the API with PM2
echo -e "${YELLOW}Step 7: Starting API server with PM2...${NC}"
pm2 delete ios-api 2>/dev/null || true
pm2 start "$PROJECT_DIR/ecosystem.config.js"
pm2 save
echo -e "${GREEN}✓ API server started${NC}"

# Step 8: Setup PM2 to start on boot
echo -e "${YELLOW}Step 8: Configuring PM2 startup...${NC}"
sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u $USER --hp /home/$USER
pm2 save
echo -e "${GREEN}✓ PM2 configured to start on boot${NC}"

# Step 9: Create management script
echo -e "${YELLOW}Step 9: Creating management commands...${NC}"
cat > "$PROJECT_DIR/scripts/api_control.sh" << 'CONTROL'
#!/bin/bash

case "$1" in
    start)
        pm2 start ios-api
        ;;
    stop)
        pm2 stop ios-api
        ;;
    restart)
        pm2 restart ios-api
        ;;
    status)
        pm2 status ios-api
        ;;
    logs)
        pm2 logs ios-api
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs}"
        exit 1
        ;;
esac
CONTROL

chmod +x "$PROJECT_DIR/scripts/api_control.sh"
echo -e "${GREEN}✓ Management script created${NC}"

# Step 10: Test the API
echo -e "${YELLOW}Step 10: Testing API health endpoint...${NC}"
sleep 2

if curl -s -f http://localhost:3000/api/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓ API is running and healthy!${NC}"
    curl -s http://localhost:3000/api/health | python3 -m json.tool
else
    echo -e "${RED}✗ API health check failed${NC}"
    echo "Check logs with: pm2 logs ios-api"
fi

echo
echo "================================================"
echo -e "${GREEN}API Backend Service Setup Complete!${NC}"
echo "================================================"
echo
echo -e "${YELLOW}Management Commands:${NC}"
echo "• Start:   $PROJECT_DIR/scripts/api_control.sh start"
echo "• Stop:    $PROJECT_DIR/scripts/api_control.sh stop"
echo "• Restart: $PROJECT_DIR/scripts/api_control.sh restart"
echo "• Status:  $PROJECT_DIR/scripts/api_control.sh status"
echo "• Logs:    $PROJECT_DIR/scripts/api_control.sh logs"
echo
echo -e "${YELLOW}PM2 Commands:${NC}"
echo "• pm2 status          - View all processes"
echo "• pm2 logs ios-api    - View logs"
echo "• pm2 monit          - Real-time monitoring"
echo "• pm2 reload ios-api  - Zero-downtime reload"
echo
echo -e "${YELLOW}Test Endpoints:${NC}"
echo "• Health: curl http://localhost:3000/api/health"
echo "• Login:  curl -X POST http://localhost:3000/api/auth/login \\"
echo "           -H 'Content-Type: application/json' \\"
echo "           -d '{\"email\":\"test@example.com\",\"password\":\"test123\"}'"
echo
echo -e "${GREEN}Your API is now running on port 3000!${NC}"