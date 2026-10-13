#!/usr/bin/env bash
# Instala el server transcriptor. Uso:  bash scripts/setup.sh
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Paquetes del sistema"
sudo apt-get update -qq
sudo apt-get install -y -qq python3-venv python3-pip ffmpeg

echo "==> Entorno virtual"
python3 -m venv .venv
.venv/bin/pip install -q --upgrade pip
.venv/bin/pip install -q -r requirements.txt

if command -v nvidia-smi >/dev/null 2>&1; then
  echo "==> GPU NVIDIA detectada: instalando cuBLAS/cuDNN para faster-whisper"
  .venv/bin/pip install -q "nvidia-cublas-cu12" "nvidia-cudnn-cu12==9.*"
fi

[ -f .env ] || { cp .env.example .env; echo "==> Creado .env (edítelo si quiere otro modelo)"; }
chmod +x scripts/*.sh
echo
echo "Listo. Levántelo con:   bash scripts/run.sh"
echo "Como servicio:           bash scripts/install-service.sh"
