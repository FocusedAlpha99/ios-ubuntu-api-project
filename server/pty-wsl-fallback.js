/**
 * Simple PTY fallback using WSL - no native compilation required
 * Drop-in replacement for node-pty that uses child_process.spawn
 */
import { spawn as childSpawn } from 'child_process';
import os from 'os';

class PtyProcess {
  constructor(command, args, options) {
    const isWindows = os.platform() === 'win32';

    // On Windows, use WSL bash; otherwise use the command directly
    if (isWindows && command === 'powershell.exe') {
      // Replace PowerShell with WSL bash for better compatibility
      this.process = childSpawn('wsl.exe', ['bash'], {
        cwd: options.cwd,
        env: options.env,
      });
    } else if (isWindows) {
      this.process = childSpawn('wsl.exe', [command, ...args], {
        cwd: options.cwd,
        env: options.env,
      });
    } else {
      this.process = childSpawn(command, args, {
        cwd: options.cwd,
        env: options.env,
      });
    }

    this.onDataCallback = null;

    // Forward stdout and stderr
    this.process.stdout.on('data', (data) => {
      if (this.onDataCallback) {
        this.onDataCallback(data.toString());
      }
    });

    this.process.stderr.on('data', (data) => {
      if (this.onDataCallback) {
        this.onDataCallback(data.toString());
      }
    });

    this.process.on('exit', () => {
      if (this.onDataCallback) {
        this.onDataCallback('\r\n[Process exited]\r\n');
      }
    });
  }

  onData(callback) {
    this.onDataCallback = callback;
  }

  write(data) {
    if (this.process.stdin.writable) {
      this.process.stdin.write(data);
    }
  }

  kill() {
    if (this.process && !this.process.killed) {
      this.process.kill();
    }
  }
}

export function spawn(command, args, options) {
  return new PtyProcess(command, args, options);
}

export default {
  spawn,
};
