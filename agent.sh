#!/bin/bash
# Simple Agent Script (for Linux/macOS with Node.js installed)

# Function to install Chocolatey (for Windows)
install_chocolatey() {
  echo "Installing Chocolatey..."
  @powershell -NoProfile -InputFormat None -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))"
}

# Function to install Node.js
install_node() {
  echo "Installing Node.js..."
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # For Linux
    curl -sL https://deb.nodesource.com/setup_14.x | sudo -E bash -
    sudo apt-get install -y nodejs
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    # For macOS
    brew install node
  elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    # For Windows (using Chocolatey)
    if ! command -v choco &> /dev/null; then
      install_chocolatey
    fi
    choco install -y nodejs
  else
    echo "Unsupported OS. Please install Node.js manually."
    exit 1
  fi
}

# Function to install Ngrok
install_ngrok() {
  echo "Installing Ngrok..."
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # For Linux
    wget https://bin.equinox.io/c/111111/ngrok-stable-linux-amd64.zip
    unzip ngrok-stable-linux-amd64.zip
    sudo mv ngrok /usr/local/bin
    rm ngrok-stable-linux-amd64.zip
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    # For macOS
    brew install --cask ngrok
  elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    # For Windows
    wget https://bin.equinox.io/c/111111/ngrok-stable-windows-amd64.zip
    unzip ngrok-stable-windows-amd64.zip
    move ngrok.exe C:\Windows\System32
    del ngrok-stable-windows-amd64.zip
  else
    echo "Unsupported OS. Please install Ngrok manually."
    exit 1
  fi
}

# Check if Node.js is installed
if ! command -v node >/dev/null; then
  install_node
else
  echo "Node.js is already installed."
fi

# Check if Ngrok is installed
if ! command -v ngrok >/dev/null; then
  install_ngrok
else
  echo "Ngrok is already installed."
fi

# Set Ngrok authentication token
NGROK_AUTH_TOKEN="2zSB66d85OsbMBJrevaGfZ3CIbU_6Yy7hXf8ECrMEUqekSEQG"  # Replace with your actual token
ngrok authtoken $NGROK_AUTH_TOKEN

# Create agent file
cat <<EOF > server.js
const WebSocket = require('ws');
const { spawn } = require('child_process');
const http = require('http');

const server = http.createServer();
const wss = new WebSocket.Server({ server });
let shell;

wss.on('connection', ws => {
  ws.on('message', msg => {
    const { type, data } = JSON.parse(msg);
    if (type === 'connect') {
      shell = spawn('bash');
      ws.send('> Shell started');
      shell.stdout.on('data', d => ws.send(d.toString()));
      shell.stderr.on('data', d => ws.send(d.toString()));
    }
    if (type === 'cmd' && shell) shell.stdin.write(data + '\\n');
    if (type === 'disconnect' && shell) shell.kill();
  });
  ws.on('close', () => shell && shell.kill());
});

server.listen(8080, () => console.log('Agent running on port 8080'));
EOF

# Start Ngrok and Node server
pkill ngrok >/dev/null 2>&1
nohup node server.js &
ngrok http 8080