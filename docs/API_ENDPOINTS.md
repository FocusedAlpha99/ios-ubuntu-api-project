# API Endpoints Documentation

## Base URL
- Production: `https://api.yourdomain.com`
- Development: `http://localhost:3000`

## Authentication

All protected endpoints require a JWT token in the Authorization header:
```
Authorization: Bearer <token>
```

---

## Endpoints

### 🔓 Public Endpoints

#### Health Check
```http
GET /api/health
```

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2025-09-21T12:00:00.000Z",
  "uptime": 3600.5,
  "service": "iOS Ubuntu API Backend",
  "version": "1.0.0"
}
```

**Status Codes:**
- `200 OK` - Service is healthy
- `503 Service Unavailable` - Service is unhealthy

---

### 🔐 Authentication Endpoints

#### Register User
```http
POST /api/auth/register
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "securepassword123",
  "name": "John Doe"
}
```

**Response:**
```json
{
  "message": "User registered successfully",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "1234567890",
    "email": "user@example.com",
    "name": "John Doe"
  }
}
```

**Status Codes:**
- `201 Created` - User registered successfully
- `400 Bad Request` - Invalid input data
- `409 Conflict` - User already exists

---

#### Login
```http
POST /api/auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "securepassword123"
}
```

**Response:**
```json
{
  "message": "Login successful",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "1234567890",
    "email": "user@example.com",
    "name": "John Doe"
  }
}
```

**Status Codes:**
- `200 OK` - Login successful
- `401 Unauthorized` - Invalid credentials
- `400 Bad Request` - Missing required fields

---

#### Refresh Token
```http
POST /api/auth/refresh
Authorization: Bearer <current_token>
```

**Response:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Status Codes:**
- `200 OK` - Token refreshed
- `401 Unauthorized` - Invalid or expired token

---

### 🔒 Protected Endpoints

#### Get User Data
```http
GET /api/data
Authorization: Bearer <token>
```

**Response:**
```json
{
  "message": "This is protected data",
  "userId": "1234567890",
  "timestamp": "2025-09-21T12:00:00.000Z",
  "data": {
    "items": ["Item 1", "Item 2", "Item 3"],
    "count": 3
  }
}
```

**Status Codes:**
- `200 OK` - Data retrieved successfully
- `401 Unauthorized` - Invalid or missing token
- `403 Forbidden` - Token expired

---

#### Execute Command
```http
POST /api/command
Authorization: Bearer <token>
Content-Type: application/json

{
  "command": "process_data"
}
```

**Response:**
```json
{
  "command": "process_data",
  "status": "executed",
  "timestamp": "2025-09-21T12:00:00.000Z",
  "result": "Processed command: process_data"
}
```

**Status Codes:**
- `200 OK` - Command executed
- `400 Bad Request` - Invalid command format
- `401 Unauthorized` - Invalid token

---

### 🧪 Test Endpoints

#### Echo Test
```http
POST /api/test/echo
Content-Type: application/json

{
  "any": "data",
  "you": "want"
}
```

**Response:**
```json
{
  "message": "Echo response",
  "receivedData": {
    "any": "data",
    "you": "want"
  },
  "headers": { ... },
  "timestamp": "2025-09-21T12:00:00.000Z"
}
```

---

## WebSocket Events

### Connection URL
```
wss://api.yourdomain.com
```

### Authentication
Include JWT token in handshake:
```javascript
const socket = io('wss://api.yourdomain.com', {
  auth: {
    token: 'your_jwt_token'
  }
});
```

### Events

#### Client → Server

**message**
```javascript
socket.emit('message', {
  type: 'chat',
  content: 'Hello server!'
});
```

**request_status**
```javascript
socket.emit('request_status');
```

#### Server → Client

**welcome**
```javascript
socket.on('welcome', (data) => {
  // data = {
  //   message: 'Connected to iOS Ubuntu API WebSocket',
  //   socketId: 'abc123',
  //   timestamp: '2025-09-21T12:00:00.000Z'
  // }
});
```

**message_response**
```javascript
socket.on('message_response', (data) => {
  // data = {
  //   original: { ... },
  //   timestamp: '2025-09-21T12:00:00.000Z',
  //   processed: true
  // }
});
```

**status_update**
```javascript
socket.on('status_update', (data) => {
  // data = {
  //   status: 'online',
  //   serverTime: '2025-09-21T12:00:00.000Z',
  //   uptime: 3600,
  //   connections: 5
  // }
});
```

**command_executed**
```javascript
socket.on('command_executed', (data) => {
  // Broadcast when command is executed via REST API
  // data = {
  //   command: 'process_data',
  //   status: 'executed',
  //   timestamp: '2025-09-21T12:00:00.000Z',
  //   result: '...'
  // }
});
```

---

## Error Responses

All errors follow this format:
```json
{
  "error": "Error message",
  "details": "Additional information (optional)",
  "timestamp": "2025-09-21T12:00:00.000Z"
}
```

### Common Error Codes

| Code | Description |
|------|-------------|
| 400 | Bad Request - Invalid input |
| 401 | Unauthorized - Missing or invalid token |
| 403 | Forbidden - Token expired |
| 404 | Not Found - Endpoint doesn't exist |
| 409 | Conflict - Resource already exists |
| 429 | Too Many Requests - Rate limit exceeded |
| 500 | Internal Server Error |
| 503 | Service Unavailable |

---

## Rate Limiting

Default limits:
- 100 requests per 15 minutes per IP
- WebSocket: 10 connections per IP
- Authentication endpoints: 5 attempts per 5 minutes

Exceeded rate limit response:
```json
{
  "error": "Too many requests from this IP, please try again later.",
  "retryAfter": 900
}
```

---

## Testing with cURL

### Test Authentication Flow
```bash
# 1. Register
TOKEN=$(curl -s -X POST http://localhost:3000/api/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"email":"test@example.com","password":"test123","name":"Test User"}' \
  | jq -r '.token')

# 2. Use token for protected endpoint
curl -X GET http://localhost:3000/api/data \
  -H "Authorization: Bearer $TOKEN"

# 3. Send command
curl -X POST http://localhost:3000/api/command \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"command":"test_command"}'
```

---

## Postman Collection

Import this collection to test all endpoints:

```json
{
  "info": {
    "name": "iOS Ubuntu API",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "item": [
    {
      "name": "Health Check",
      "request": {
        "method": "GET",
        "header": [],
        "url": "{{baseUrl}}/api/health"
      }
    },
    {
      "name": "Register",
      "request": {
        "method": "POST",
        "header": [
          {
            "key": "Content-Type",
            "value": "application/json"
          }
        ],
        "body": {
          "mode": "raw",
          "raw": "{\"email\":\"test@example.com\",\"password\":\"test123\",\"name\":\"Test User\"}"
        },
        "url": "{{baseUrl}}/api/auth/register"
      }
    }
  ],
  "variable": [
    {
      "key": "baseUrl",
      "value": "http://localhost:3000"
    }
  ]
}
```

---

*Last Updated: September 21, 2025*