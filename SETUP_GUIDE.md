# iOS to Ubuntu API Project - Complete Setup Guide

## Quick Start (5 Minutes)

```bash
# 1. Run the API setup
cd ~/ios_ubuntu_api_project
./scripts/setup_api_service.sh

# 2. Run the Cloudflare Tunnel setup
./scripts/setup_cloudflare_api_tunnel.sh

# 3. Test the connection
curl https://api.timrattigan.com/api/health
```

If the test works, your iOS app can now connect to your Ubuntu server from anywhere!

## Detailed Setup Instructions

### Prerequisites

- Ubuntu 24.04 LTS
- Cloudflare account (free tier is fine)
- Domain registered with Cloudflare (timrattigan.com)
- iOS development environment (Xcode)

### Step 1: API Backend Setup

1. Navigate to project directory:
```bash
cd ~/ios_ubuntu_api_project
```

2. Run the API setup script:
```bash
./scripts/setup_api_service.sh
```

This will:
- Install Node.js 20.x LTS
- Install PM2 process manager
- Install all dependencies
- Create environment configuration
- Start the API server
- Configure auto-start on boot

3. Verify the API is running:
```bash
curl http://localhost:3000/api/health
```

You should see a JSON response with server status.

### Step 2: Cloudflare Tunnel Setup

1. Run the tunnel setup script:
```bash
./scripts/setup_cloudflare_api_tunnel.sh
```

2. When prompted, log in to your Cloudflare account in the browser.

3. The script will:
- Create a tunnel named "ios-api-tunnel"
- Configure routing for api.timrattigan.com
- Set up systemd service for auto-start
- Create DNS records automatically

4. Start the tunnel:
```bash
sudo systemctl start cloudflared-api
```

5. Test external access:
```bash
curl https://api.timrattigan.com/api/health
```

### Step 3: iOS App Integration

1. Copy the Swift files from `ios_templates/` to your Xcode project:
- APIManager.swift
- WebSocketManager.swift
- ContentView.swift (example usage)

2. Update the base URL in APIManager.swift if using a different domain:
```swift
static let baseURL = "https://api.timrattigan.com"
```

3. Add to your Info.plist:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
</dict>
```

4. Test the connection in your iOS app:
```swift
Task {
    do {
        let health = try await APIManager.shared.checkHealth()
        print("Server status: \(health.status)")
    } catch {
        print("Connection failed: \(error)")
    }
}
```

## Testing

### Test Authentication

1. Using curl:
```bash
# Login
curl -X POST https://api.timrattigan.com/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"test@example.com","password":"test123"}'

# You'll receive a JWT token in the response
```

2. Test protected endpoint:
```bash
curl https://api.timrattigan.com/api/data \
  -H 'Authorization: Bearer YOUR_JWT_TOKEN'
```

### Test WebSocket Connection

Using Node.js:
```javascript
const io = require('socket.io-client');
const socket = io('wss://api.timrattigan.com', {
    auth: {
        token: 'YOUR_JWT_TOKEN'
    }
});

socket.on('connect', () => {
    console.log('Connected to WebSocket');
});
```

## Management Commands

### API Server

```bash
# View status
pm2 status ios-api

# View logs
pm2 logs ios-api

# Restart
pm2 restart ios-api

# Stop
pm2 stop ios-api

# Monitor (real-time)
pm2 monit
```

### Cloudflare Tunnel

```bash
# View status
sudo systemctl status cloudflared-api

# View logs
sudo journalctl -u cloudflared-api -f

# Restart
sudo systemctl restart cloudflared-api

# Stop
sudo systemctl stop cloudflared-api
```

## Troubleshooting

### API Not Accessible Externally

1. Check API is running:
```bash
pm2 status ios-api
curl http://localhost:3000/api/health
```

2. Check tunnel is running:
```bash
sudo systemctl status cloudflared-api
```

3. Check DNS propagation:
```bash
nslookup api.timrattigan.com
```

### iOS App Can't Connect

1. Verify URL is correct in APIManager.swift
2. Check network permissions in Info.plist
3. Test with curl from terminal to confirm server is accessible
4. Check for any firewall issues

### WebSocket Connection Fails

1. Ensure JWT token is valid
2. Check WebSocket port (should be same as API port with PM2)
3. Verify Cloudflare Tunnel supports WebSocket (it does by default)

### High Latency

1. Check server resources:
```bash
htop
pm2 monit
```

2. Consider upgrading Cloudflare plan for better routing
3. Implement caching in API responses

## Security Checklist

- [ ] Changed JWT secret in .env file
- [ ] Configured rate limiting
- [ ] Enabled CORS properly
- [ ] Using HTTPS only (via Cloudflare)
- [ ] Storing passwords hashed (bcrypt)
- [ ] Input validation enabled
- [ ] No sensitive data in logs
- [ ] Regular security updates

## Performance Optimization

### API Server

1. Enable clustering in PM2:
```javascript
// ecosystem.config.js
instances: 'max', // Uses all CPU cores
```

2. Add Redis for caching (optional):
```bash
sudo apt install redis-server
npm install redis
```

3. Implement response compression:
```javascript
const compression = require('compression');
app.use(compression());
```

### iOS App

1. Implement request caching
2. Use background URL sessions for large transfers
3. Batch API requests when possible
4. Implement proper retry logic with exponential backoff

## Monitoring

### Setup Monitoring Dashboard

1. PM2 Web Dashboard:
```bash
pm2 install pm2-server-monit
pm2 web
```

2. Access at: http://localhost:9615

### Logging

Logs are stored in:
- API logs: `~/ios_ubuntu_api_project/logs/`
- PM2 logs: `~/.pm2/logs/`
- Tunnel logs: `sudo journalctl -u cloudflared-api`

## Backup & Recovery

### Backup Configuration

```bash
# Backup script
cat > ~/ios_ubuntu_api_project/scripts/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/home/$USER/backups/ios-api-$(date +%Y%m%d)"
mkdir -p $BACKUP_DIR

# Backup configuration
cp -r ~/ios_ubuntu_api_project/server/.env $BACKUP_DIR/
cp -r ~/.cloudflared $BACKUP_DIR/

# Backup PM2 configuration
pm2 save
cp ~/.pm2/dump.pm2 $BACKUP_DIR/

echo "Backup completed to $BACKUP_DIR"
EOF

chmod +x ~/ios_ubuntu_api_project/scripts/backup.sh
```

### Restore Process

1. Restore files from backup
2. Run setup scripts again
3. Restart services

## Cost Analysis

### Current Setup (Self-Hosted)
- **Cloudflare**: Free tier
- **Ubuntu Server**: Your hardware + electricity (~$10/month)
- **Domain**: Already owned
- **Total**: ~$10/month

### Alternative Cloud Costs
- **Vercel**: $20/month (Pro)
- **AWS EC2**: $30-50/month
- **DigitalOcean**: $24/month
- **Google Cloud**: $25-40/month

### Savings: ~$15-40/month

## Next Steps

1. **Add Database**: PostgreSQL or MongoDB for data persistence
2. **Implement Caching**: Redis for improved performance
3. **Add Monitoring**: Grafana + Prometheus for metrics
4. **Setup CI/CD**: GitHub Actions for automated deployment
5. **Add Push Notifications**: Apple Push Notification Service
6. **Implement GraphQL**: For more efficient data fetching
7. **Add File Storage**: MinIO for S3-compatible storage

## Support & Documentation

- **Project Documentation**: ~/ios_ubuntu_api_project/docs/
- **API Documentation**: http://localhost:3000/api-docs (when implemented)
- **Cloudflare Docs**: https://developers.cloudflare.com/cloudflare-one/
- **PM2 Docs**: https://pm2.keymetrics.io/docs/

---

**Last Updated**: September 21, 2025
**Version**: 1.0.0
**Status**: Production Ready