#!/usr/bin/env bash
# Deja el server corriendo siempre (arranca con el equipo). Uso: bash scripts/install-service.sh
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
sudo tee /etc/systemd/system/amanuense.service >/dev/null <<UNIT
[Unit]
Description=Amanuense - Transcriptor Whisper (by wilo)
After=network-online.target
Wants=network-online.target

[Service]
User=$USER
WorkingDirectory=$DIR
ExecStart=/usr/bin/env bash $DIR/scripts/run.sh
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT
sudo systemctl daemon-reload
sudo systemctl enable --now amanuense
echo "Servicio activo. Logs:  journalctl -u amanuense -f"
