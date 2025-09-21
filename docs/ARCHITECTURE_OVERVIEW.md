# iOS to Ubuntu API Architecture Documentation

## Project Overview
This documentation outlines the complete architecture for connecting a future iOS application to an Ubuntu home server (192.168.1.190) using Cloudflare Tunnel for secure, reliable remote access.

**Last Updated**: September 21, 2025

## Architecture Decision: Cloudflare Tunnel

### Why Cloudflare Tunnel?
After comprehensive analysis of WireGuard VPN, Direct HTTPS, and Reverse Proxy options, Cloudflare Tunnel emerges as the optimal solution:

1. **Zero iOS Battery Impact** - No persistent VPN connection required
2. **Dynamic IP Handling** - Automatic handling of residential IP changes
3. **Carrier NAT Compatible** - Works seamlessly on cellular networks
4. **WebSocket Support** - Real-time bidirectional communication
5. **Free Tier Available** - No additional costs for basic usage
6. **Built-in Security** - DDoS protection, SSL/TLS, rate limiting
7. **Simple iOS Integration** - Standard URLSession, no VPN profiles

## System Architecture

```
┌─────────────┐         ┌──────────────┐         ┌─────────────────┐
│   iOS App   │────────▶│  Cloudflare  │────────▶│  Ubuntu Server  │
│  (Swift)    │◀────────│    Tunnel    │◀────────│  192.168.1.190  │
└─────────────┘         └──────────────┘         └─────────────────┘
     ▲                                                     │
     │                                                     │
     └─────────────── api.timrattigan.com ────────────────┘
```

## Network Details

### Public Endpoint
- **Domain**: `api.timrattigan.com`
- **Protocol**: HTTPS (managed by Cloudflare)
- **Ports**: 443 (HTTPS), WSS for WebSocket

### Internal Server
- **Local IP**: 192.168.1.190
- **API Port**: 3000 (Node.js/Express)
- **WebSocket Port**: 3001 (Socket.io)
- **Public IP**: 173.48.240.42 (dynamic, handled by tunnel)

## API Endpoints Structure

### REST API
- `GET /api/health` - Health check endpoint
- `POST /api/auth/login` - JWT authentication
- `POST /api/auth/refresh` - Token refresh
- `GET /api/data` - Sample data endpoint
- `POST /api/command` - Execute commands

### WebSocket Events
- `connection` - Client connects
- `authenticated` - Client provides valid JWT
- `message` - Bidirectional messaging
- `status_update` - Server push updates
- `disconnect` - Client disconnects

## Security Architecture

### Authentication Flow
1. iOS app sends credentials to `/api/auth/login`
2. Server validates and returns JWT token
3. iOS stores token in Keychain
4. All subsequent requests include JWT in Authorization header
5. Token refresh before expiration

### Security Layers
1. **Cloudflare Protection** - DDoS, rate limiting, WAF
2. **SSL/TLS** - Automatic certificate management
3. **JWT Authentication** - Stateless token-based auth
4. **API Rate Limiting** - Per-client request throttling
5. **Input Validation** - Server-side sanitization

## iOS App Architecture

### Networking Layer
```swift
// APIManager handles all network requests
APIManager
├── AuthenticationService
│   ├── login()
│   ├── refreshToken()
│   └── logout()
├── APIService
│   ├── get()
│   ├── post()
│   ├── put()
│   └── delete()
└── WebSocketService
    ├── connect()
    ├── send()
    └── receive()
```

### Data Flow
1. User action triggers API call
2. APIManager adds authentication headers
3. Request sent to Cloudflare endpoint
4. Cloudflare tunnels to Ubuntu server
5. Server processes and responds
6. Response tunneled back through Cloudflare
7. iOS app processes response

## Ubuntu Server Architecture

### Software Stack
- **OS**: Ubuntu 24.04 LTS
- **Runtime**: Node.js 20.x LTS
- **Framework**: Express.js
- **WebSocket**: Socket.io
- **Process Manager**: PM2
- **Reverse Proxy**: Cloudflare Tunnel (replaces nginx)

### Directory Structure
```
/home/pryzm/ios_ubuntu_api_project/
├── server/
│   ├── app.js           # Express application
│   ├── routes/          # API routes
│   ├── middleware/      # Auth, logging, etc.
│   ├── services/        # Business logic
│   ├── models/          # Data models
│   └── config/          # Configuration files
├── logs/
│   ├── access.log
│   └── error.log
└── .env                 # Environment variables
```

## Failover Strategy

### Primary Path
iOS App → Cloudflare → Ubuntu Server

### Fallback Path (if Ubuntu offline)
iOS App → Vercel Serverless Functions

### Implementation
```swift
// iOS automatically tries primary, then fallback
let primaryURL = "https://api.timrattigan.com"
let fallbackURL = "https://backup.vercel.app"
```

## Monitoring & Observability

### Health Checks
- Cloudflare monitors tunnel status
- iOS app pings `/api/health` every 30 seconds
- Ubuntu server monitors with systemd

### Logging
- Cloudflare Analytics for traffic patterns
- Server logs with Winston/Morgan
- iOS app logs with OSLog

### Alerts
- Tunnel down notifications
- High error rate alerts
- Resource usage warnings

## Development vs Production

### Development
- Local testing without tunnel
- iOS Simulator connects to localhost
- Mock authentication for testing

### Production
- All traffic through Cloudflare Tunnel
- Real authentication required
- Full monitoring enabled

## Cost Analysis

### Cloudflare (Monthly)
- Free tier: 0 USD (sufficient for most use cases)
- Pro tier: $20 USD (if advanced features needed)

### Ubuntu Server
- Electricity: ~$5-10 USD
- Internet: Already paying for residential
- Hardware: One-time cost (already have)

### Comparison to Cloud
- Vercel Pro: $20/month
- AWS EC2: $30-50/month
- Self-hosted: $5-10/month

## Future Enhancements

### Phase 1 (Current)
- Basic REST API
- JWT authentication
- WebSocket support

### Phase 2 (Planned)
- GraphQL endpoint
- File upload/download
- Push notifications

### Phase 3 (Future)
- Multi-region failover
- Horizontal scaling
- AI/ML integration

## Quick Reference

### Key URLs
- API Endpoint: `https://api.timrattigan.com`
- WebSocket: `wss://api.timrattigan.com`
- Health Check: `https://api.timrattigan.com/api/health`

### Key Ports
- Internal API: 3000
- Internal WebSocket: 3001
- External HTTPS: 443

### Key Commands
```bash
# Start API server
pm2 start /home/pryzm/ios_ubuntu_api_project/server/app.js

# Check tunnel status
cloudflared tunnel info

# View logs
pm2 logs

# Restart services
sudo systemctl restart cloudflared
pm2 restart all
```

## Security Checklist

- [ ] Cloudflare Tunnel configured
- [ ] JWT secret in environment variables
- [ ] Rate limiting enabled
- [ ] Input validation implemented
- [ ] CORS properly configured
- [ ] Health check endpoint working
- [ ] Monitoring alerts set up
- [ ] Backup failover tested
- [ ] SSL/TLS verified
- [ ] Logs properly rotated

---

*This architecture provides a robust, secure, and scalable foundation for iOS to Ubuntu server communication with minimal complexity and cost.*