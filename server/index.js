import express from 'express';
import cors from 'cors';
import { createServer } from 'http';
import { Server as SocketIOServer } from 'socket.io';
import os from 'os';
import { spawn as childSpawn } from 'child_process';

const PORT = Number(process.env.PORT) || 3001;

const app = express();
app.use(cors({ origin: '*' }));

const httpServer = createServer(app);
const io = new SocketIOServer(httpServer, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
  },
});

let pty;
let fallbackPty;
let terminalBackend = 'node-pty';

const loadFallback = async () => {
  if (!fallbackPty) {
    const fallbackModule = await import('./pty-wsl-fallback.js');
    fallbackPty = fallbackModule.default ?? fallbackModule;
  }
  terminalBackend = 'wsl-fallback';
  console.log('Using WSL fallback for terminal');
  return fallbackPty;
};

const createPowerShellFallback = () => {
  terminalBackend = 'powershell-child';
  console.log('Using PowerShell child_process fallback for terminal');

  const child = childSpawn('powershell.exe', [], {
    cwd: process.env.HOME ?? process.cwd(),
    env: process.env,
    stdio: 'pipe',
    windowsHide: false,
  });

  let dataHandler = null;
  const emitData = (chunk) => {
    if (dataHandler) {
      dataHandler(chunk.toString());
    }
  };

  child.stdout.on('data', emitData);
  child.stderr.on('data', emitData);
  child.on('exit', () => {
    if (dataHandler) {
      dataHandler('\r\n[PowerShell process exited]\r\n');
    }
  });

  return {
    onData(handler) {
      dataHandler = handler;
    },
    write(data) {
      if (child.stdin.writable) {
        child.stdin.write(data);
      }
    },
    kill() {
      if (!child.killed) {
        child.kill();
      }
    },
  };
};

try {
  const ptyModule = await import('node-pty');
  pty = ptyModule.default ?? ptyModule;
  console.log('Using node-pty for terminal');
} catch (error) {
  console.warn('node-pty not available, using fallback:', error.message);
  if (os.platform() === 'win32') {
    pty = await loadFallback();
  } else {
    throw error;
  }
}

const isWindows = os.platform() === 'win32';
const shellCommand = isWindows ? 'powershell.exe' : 'bash';
const shellArgs = [];

const activePtys = new Map();

const spawnPty = async () => {
  try {
    return pty.spawn(shellCommand, shellArgs, {
      name: 'xterm-color',
      cols: 80,
      rows: 30,
      cwd: process.env.HOME ?? process.cwd(),
      env: process.env,
    });
  } catch (error) {
    if (terminalBackend === 'node-pty') {
      try {
        pty = await loadFallback();
        return pty.spawn(shellCommand, shellArgs, {
          name: 'xterm-color',
          cols: 80,
          rows: 30,
          cwd: process.env.HOME ?? process.cwd(),
          env: process.env,
        });
      } catch (fallbackError) {
        if (isWindows) {
          console.warn(
            'WSL fallback failed, switching to PowerShell child_process fallback...',
            fallbackError
          );
          return createPowerShellFallback();
        }
        throw fallbackError;
      }
    }

    if (terminalBackend === 'wsl-fallback' && isWindows) {
      console.warn(
        'WSL fallback spawn failed, switching to PowerShell child_process fallback...',
        error
      );
      return createPowerShellFallback();
    }

    throw error;
  }
};

io.on('connection', async (socket) => {
  console.log('Client connected');

  let ptyProcess;

  try {
    ptyProcess = await spawnPty();
  } catch (error) {
    console.error('CRITICAL ERROR: Failed to spawn PTY process.', error);
    socket.emit(
      'terminal.output',
      '\r\n[Server] Unable to start terminal session. Check server logs.\r\n'
    );
    socket.disconnect(true);
    return;
  }

  activePtys.set(socket.id, ptyProcess);

  ptyProcess.onData((data) => {
    socket.emit('terminal.output', data);
  });

  socket.on('terminal.input', (data) => {
    if (data) {
      ptyProcess.write(Buffer.isBuffer(data) ? data.toString() : data);
    }
  });

  socket.on('disconnect', () => {
    console.log('Client disconnected');
    const proc = activePtys.get(socket.id);
    if (proc) {
      try {
        proc.kill();
      } catch (error) {
        console.error('Failed to clean up PTY process', error);
      } finally {
        activePtys.delete(socket.id);
      }
    }
  });
});

app.get('/health', (_req, res) => {
  res.json({
    status: 'ok',
    service: 'Project Swivel PTY engine',
    timestamp: new Date().toISOString(),
  });
});

httpServer.listen(PORT, () => {
  console.log(`Swivel PTY server listening on http://localhost:${PORT}`);
});
