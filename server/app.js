// iOS Ubuntu API Backend Server
// Express.js server with JWT auth and WebSocket support

import { createRequire } from 'module';
const require = createRequire(import.meta.url);

require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const { Server } = require('socket.io');
const http = require('http');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');
const { body, validationResult } = require('express-validator');

// Initialize Express app
const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: "*", // Configure for your iOS app in production
    methods: ["GET", "POST"]
  }
});

// Configuration
const PORT = process.env.PORT || 3000;
const WS_PORT = process.env.WS_PORT || 3001;
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';
const JWT_EXPIRY = '7d';

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(morgan('combined'));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.'
});

app.use('/api/', limiter);

// In-memory user store (replace with database in production)
const users = new Map();
// Sample user for testing
users.set('test@example.com', {
  id: '1',
  email: 'test@example.com',
  password: '$2b$10$ZJ6PqKqtHqN.hGpTYLk3XeV4vUeKH.MlD9NpmD8PqKvxAQrMqNgXi', // password: test123
  name: 'Test User'
});

// Helper functions
function generateToken(userId) {
  return jwt.sign({ userId }, JWT_SECRET, { expiresIn: JWT_EXPIRY });
}

function verifyToken(token) {
  try {
    return jwt.verify(token, JWT_SECRET);
  } catch (error) {
    return null;
  }
}

// Authentication middleware
function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  const decoded = verifyToken(token);
  if (!decoded) {
    return res.status(403).json({ error: 'Invalid or expired token' });
  }

  req.userId = decoded.userId;
  next();
}

// ============== ROUTES ==============

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    service: 'iOS Ubuntu API Backend',
    version: '1.0.0'
  });
});

// Authentication endpoints
app.post('/api/auth/register',
  [
    body('email').isEmail().normalizeEmail(),
    body('password').isLength({ min: 6 }),
    body('name').notEmpty().trim()
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { email, password, name } = req.body;

    if (users.has(email)) {
      return res.status(409).json({ error: 'User already exists' });
    }

    try {
      const hashedPassword = await bcrypt.hash(password, 10);
      const userId = Date.now().toString();

      users.set(email, {
        id: userId,
        email,
        password: hashedPassword,
        name
      });

      const token = generateToken(userId);

      res.status(201).json({
        message: 'User registered successfully',
        token,
        user: { id: userId, email, name }
      });
    } catch (error) {
      console.error('Registration error:', error);
      res.status(500).json({ error: 'Registration failed' });
    }
  }
);

app.post('/api/auth/login',
  [
    body('email').isEmail().normalizeEmail(),
    body('password').notEmpty()
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { email, password } = req.body;
    const user = users.get(email);

    if (!user) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    try {
      const validPassword = await bcrypt.compare(password, user.password);

      if (!validPassword) {
        return res.status(401).json({ error: 'Invalid credentials' });
      }

      const token = generateToken(user.id);

      res.json({
        message: 'Login successful',
        token,
        user: {
          id: user.id,
          email: user.email,
          name: user.name
        }
      });
    } catch (error) {
      console.error('Login error:', error);
      res.status(500).json({ error: 'Login failed' });
    }
  }
);

app.post('/api/auth/refresh', authenticateToken, (req, res) => {
  const newToken = generateToken(req.userId);
  res.json({ token: newToken });
});

// Protected data endpoints
app.get('/api/data', authenticateToken, (req, res) => {
  res.json({
    message: 'This is protected data',
    userId: req.userId,
    timestamp: new Date().toISOString(),
    data: {
      items: ['Item 1', 'Item 2', 'Item 3'],
      count: 3
    }
  });
});

app.post('/api/command', authenticateToken,
  [body('command').notEmpty().trim()],
  (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { command } = req.body;

    // Process command (example)
    const result = {
      command,
      status: 'executed',
      timestamp: new Date().toISOString(),
      result: `Processed command: ${command}`
    };

    // Emit to WebSocket clients
    io.emit('command_executed', result);

    res.json(result);
  }
);

// Test endpoint for iOS development
app.post('/api/test/echo', (req, res) => {
  res.json({
    message: 'Echo response',
    receivedData: req.body,
    headers: req.headers,
    timestamp: new Date().toISOString()
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Endpoint not found' });
});

// Error handler
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

// ============== WEBSOCKET ==============

// WebSocket authentication middleware
io.use((socket, next) => {
  const token = socket.handshake.auth.token;

  if (!token) {
    return next(new Error('Authentication required'));
  }

  const decoded = verifyToken(token);
  if (!decoded) {
    return next(new Error('Invalid token'));
  }

  socket.userId = decoded.userId;
  next();
});

// WebSocket connection handler
io.on('connection', (socket) => {
  console.log(`Client connected: ${socket.id} (User: ${socket.userId})`);

  // Join user-specific room
  socket.join(`user:${socket.userId}`);

  // Send welcome message
  socket.emit('welcome', {
    message: 'Connected to iOS Ubuntu API WebSocket',
    socketId: socket.id,
    timestamp: new Date().toISOString()
  });

  // Handle messages from client
  socket.on('message', (data) => {
    console.log(`Message from ${socket.userId}:`, data);

    // Echo back with timestamp
    socket.emit('message_response', {
      original: data,
      timestamp: new Date().toISOString(),
      processed: true
    });
  });

  // Handle status request
  socket.on('request_status', () => {
    socket.emit('status_update', {
      status: 'online',
      serverTime: new Date().toISOString(),
      uptime: process.uptime(),
      connections: io.engine.clientsCount
    });
  });

  // Handle disconnection
  socket.on('disconnect', () => {
    console.log(`Client disconnected: ${socket.id}`);
  });
});

// ============== SERVER START ==============

// Start Express server
server.listen(PORT, '0.0.0.0', () => {
  console.log(`
╔════════════════════════════════════════════╗
║     iOS Ubuntu API Backend Server         ║
╠════════════════════════════════════════════╣
║  API Server:  http://localhost:${PORT}       ║
║  WebSocket:   ws://localhost:${PORT}         ║
║  Health:      http://localhost:${PORT}/api/health ║
║                                            ║
║  Environment: ${process.env.NODE_ENV || 'development'}              ║
║  Started:     ${new Date().toISOString()} ║
╚════════════════════════════════════════════╝

Ready to accept connections from iOS app via Cloudflare Tunnel!

Test credentials:
  Email: test@example.com
  Password: test123

Test with curl:
  curl http://localhost:${PORT}/api/health
`);
});