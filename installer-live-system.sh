#!/bin/bash
set -euo pipefail

# We are run as root inside the TARGET system (Calamares chroot).

export DEBIAN_FRONTEND=noninteractive

log() {
    echo "[jinstaller] $*" >&2
}

# --- Ensure basic tools ------------------------------------------------------

if ! command -v curl >/dev/null 2>&1; then
    log "curl not found, installing it..."
    apt update
    apt install -y curl
fi

# --- Install Ollama ----------------------------------------------------------

log "Installing Ollama..."

if ! command -v ollama >/dev/null 2>&1; then
    if ! curl -fsSL https://ollama.com/install.sh | sh; then
        log "WARNING: Ollama install failed, skipping Ollama setup."
    fi
else
    log "Ollama already present, skipping install.sh."
fi

if command -v ollama >/dev/null 2>&1; then
    log "Ollama version:"
    ollama --version || true

    # This will download a large model; OK to fail without killing the whole install.
    if ! ollama pull llama3.1:8b; then
        log "WARNING: Failed to pull llama3.1:8b (network / disk issue?). User can pull it later."
    fi

    # Enable Ollama service for next boot; can't start it now.
    if command -v systemctl >/dev/null 2>&1; then
        systemctl enable ollama || log "WARNING: Failed to enable ollama service (but install probably worked)."
    fi
fi

# --- Install Open WebUI dependencies ----------------------------------------

log "Installing Open WebUI dependencies..."

apt update
apt install -y python3 python3-venv python3-pip git

# --- Create service user -----------------------------------------------------

if ! id -u openwebui >/dev/null 2>&1; then
    log "Creating user 'openwebui'..."
    useradd -m -s /bin/bash openwebui
else
    log "User 'openwebui' already exists, reusing."
fi

# --- Prepare /opt/openwebui --------------------------------------------------

mkdir -p /opt/openwebui
chown -R openwebui:openwebui /opt/openwebui

# --- Install Open WebUI into a venv -----------------------------------------

log "Installing Open WebUI (pip) ..."

sudo -u openwebui bash <<'EOF'
set -euo pipefail
cd /opt/openwebui
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install open-webui

mkdir -p ~/.config/open-webui
cat > ~/.config/open-webui/config.json <<CONFIG
{
  "OLLAMA_BASE_URL": "http://localhost:11434",
  "WEBUI_PORT": 3000,
  "ALLOW_REMOTE_ACCESS": false,
  "DEBUG": false
}
CONFIG
EOF

# --- Systemd service unit ----------------------------------------------------

log "Creating systemd service for Open WebUI..."

cat > /etc/systemd/system/openwebui.service <<'SERVICE'
[Unit]
Description=Open WebUI Service
After=network.target ollama.service

[Service]
User=openwebui
WorkingDirectory=/opt/openwebui
Environment="PATH=/opt/openwebui/venv/bin"
ExecStart=/opt/openwebui/venv/bin/open-webui serve --host 0.0.0.0 --port 3000
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE

# Enable for next boot only; cannot start it now inside chroot
if command -v systemctl >/dev/null 2>&1; then
    systemctl enable openwebui || log "WARNING: Failed to enable openwebui service."
fi

log "Open WebUI will be available on http://localhost:3000 after first boot."
log "It is configured to talk to Ollama at http://localhost:11434."
