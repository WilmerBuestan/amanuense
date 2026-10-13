```
░█████╗░███╗░░░███╗░█████╗░███╗░░██╗██╗░░░██╗███████╗███╗░░██╗░██████╗███████╗
██╔══██╗████╗░████║██╔══██╗████╗░██║██║░░░██║██╔════╝████╗░██║██╔════╝██╔════╝
███████║██╔████╔██║███████║██╔██╗██║██║░░░██║█████╗░░██╔██╗██║╚█████╗░█████╗░░
██╔══██║██║╚██╔╝██║██╔══██║██║╚████║██║░░░██║██╔══╝░░██║╚████║░╚═══██╗██╔══╝░░
██║░░██║██║░╚═╝░██║██║░░██║██║░╚███║╚██████╔╝███████╗██║░╚███║██████╔╝███████╗
╚═╝░░╚═╝╚═╝░░░░░╚═╝╚═╝░░╚═╝╚═╝░░╚══╝░╚═════╝░╚══════╝╚═╝░░╚══╝╚═════╝░╚══════╝
```

# 🎙️ Amanuense

Notas por voz → texto literal → `.md` local → Obsidian.
Ver el plan completo en [`docs/CA.md`](docs/CA.md) · Llevarlo al Ubuntu Server: [`docs/DEPLOY-UBUNTU.md`](docs/DEPLOY-UBUNTU.md).

```
Grabador de voz/
├── docs/CA.md            Curso de acción y fases
├── docs/DEPLOY-UBUNTU.md Guía para el Ubuntu Server
├── app/                  F1 — App Flutter (Android + Linux)
└── server/               F0 — Transcriptor (FastAPI + faster-whisper)
    ├── app/
    │   ├── main.py       Endpoints
    │   ├── engine.py     Motor intercambiable (whisper / fake)
    │   ├── markdown.py   Arma la nota .md
    │   └── config.py     Config por .env
    ├── static/index.html Página web: subir audio → bajar .md
    ├── banner.txt / firma.txt  Marca Amanuense · by wilo
    ├── scripts/
    │   ├── setup.sh            Instala todo
    │   ├── run.sh              Arranca el server
    │   ├── install-service.sh  Lo deja como servicio systemd
    │   └── transcribir.sh      Audio → .md desde la terminal
    └── tests/test_api.py
```

## F0 — Levantar el server (Ubuntu Server)

```bash
# 1. Copiar el proyecto al server (desde la laptop)
scp -r "~/Desktop/proyectos_wilo/Grabador de voz/server" usuario@IP_SERVER:~/amanuense-server

# 2. En el server
cd ~/amanuense-server
bash scripts/setup.sh
bash scripts/run.sh          # la 1ra vez descarga el modelo (~500 MB con 'small')
```

Verificar:
```bash
curl http://localhost:8000/health
```

### Opción Docker (F0.1 — recomendada)
```bash
cd ~/amanuense-server
cp .env.example .env          # elegir WHISPER_MODEL (base o small en CPU)
docker compose up -d --build  # arranca solo al reiniciar la máquina
docker compose logs -f        # la 1ra vez descarga el modelo
```
Cambiar de modelo: editar `.env` y `docker compose up -d`.

### Usarlo
- **Desde el celular o la PC (navegador):** `http://IP_SERVER:8000` → sube el audio → se descarga el `.md`.
- **Desde la terminal:**
  ```bash
  AMANUENSE_SERVER=http://IP_SERVER:8000 bash scripts/transcribir.sh clase.m4a "Clase SOA unidad 2"
  ```
- **API (para la app Flutter):**
  - `GET  /health`
  - `POST /transcribe`     → JSON `{text, language, duration, processing_s, segments[]}`
  - `POST /transcribe/md`  → archivo `.md` (form: `audio`, `title`, `language`)
  - Docs interactivas: `http://IP_SERVER:8000/docs`

### Dejarlo como servicio (arranca solo)
```bash
bash scripts/install-service.sh
journalctl -u amanuense -f
```

### Elegir modelo (`server/.env`)
| Hardware | `WHISPER_MODEL` | Nota |
|---|---|---|
| Solo CPU, pocos núcleos | `base` | Rápido, calidad aceptable |
| Solo CPU | `small` | Equilibrado (por defecto) |
| GPU NVIDIA ≥ 6 GB | `large-v3-turbo` | Casi perfecto y rápido |
| GPU NVIDIA ≥ 10 GB | `large-v3` | Máxima calidad |

Luego de cambiarlo: `sudo systemctl restart amanuense`.

### Pruebas (sin descargar modelo)
```bash
.venv/bin/pip install -r requirements-dev.txt
ENGINE=fake .venv/bin/pytest -q
```

### Firewall (si usa ufw) — solo LAN
```bash
sudo ufw allow from 192.168.0.0/16 to any port 8000 proto tcp
```

## F1 — App Flutter (`app/`)

```bash
cd app
flutter run -d R5CTA27JLLA   # celular por USB
flutter run -d linux         # PC
flutter build apk --release  # APK en build/app/outputs/flutter-apk/
```
- ⚙️ Configuración: dirección del server (`http://IP:8000`) y carpeta de notas.
- Notas en `Documents/Amanuense` (Android, pide "Acceso a todos los archivos") o `~/Documentos/Amanuense` (PC).
- Si falla la transcripción, el audio queda guardado y se puede **Reintentar**.

## Formato de la nota
```markdown
---
titulo: "Clase SOA unidad 2"
fecha: 2026-10-13 08:23
duracion: 52:10
idioma: es
origen: clase.m4a
tags: [amanuense, transcripcion]
estado: literal
---

# Clase SOA unidad 2

## Transcripción

**[00:00]** Buenos días, hoy vamos a ver WSDL...
**[01:02]** ...

---
_Transcrito con Amanuense · by wilo (Wilmer Buestan)_
```

---

```
████████████████████████████████████████████████████████████████████████████████████████████████████████
█░░░░░░░░░░░░░░███░░░░░░░░██░░░░░░░░████░░░░░░██████████░░░░░░█░░░░░░░░░░█░░░░░░█████████░░░░░░░░░░░░░░█
█░░▄▀▄▀▄▀▄▀▄▀░░███░░▄▀▄▀░░██░░▄▀▄▀░░████░░▄▀░░██████████░░▄▀░░█░░▄▀▄▀▄▀░░█░░▄▀░░█████████░░▄▀▄▀▄▀▄▀▄▀░░█
█░░▄▀░░░░░░▄▀░░███░░░░▄▀░░██░░▄▀░░░░████░░▄▀░░██████████░░▄▀░░█░░░░▄▀░░░░█░░▄▀░░█████████░░▄▀░░░░░░▄▀░░█
█░░▄▀░░██░░▄▀░░█████░░▄▀▄▀░░▄▀▄▀░░██████░░▄▀░░██████████░░▄▀░░███░░▄▀░░███░░▄▀░░█████████░░▄▀░░██░░▄▀░░█
█░░▄▀░░░░░░▄▀░░░░███░░░░▄▀▄▀▄▀░░░░██████░░▄▀░░██░░░░░░██░░▄▀░░███░░▄▀░░███░░▄▀░░█████████░░▄▀░░██░░▄▀░░█
█░░▄▀▄▀▄▀▄▀▄▀▄▀░░█████░░░░▄▀░░░░████████░░▄▀░░██░░▄▀░░██░░▄▀░░███░░▄▀░░███░░▄▀░░█████████░░▄▀░░██░░▄▀░░█
█░░▄▀░░░░░░░░▄▀░░███████░░▄▀░░██████████░░▄▀░░██░░▄▀░░██░░▄▀░░███░░▄▀░░███░░▄▀░░█████████░░▄▀░░██░░▄▀░░█
█░░▄▀░░████░░▄▀░░███████░░▄▀░░██████████░░▄▀░░░░░░▄▀░░░░░░▄▀░░███░░▄▀░░███░░▄▀░░█████████░░▄▀░░██░░▄▀░░█
█░░▄▀░░░░░░░░▄▀░░███████░░▄▀░░██████████░░▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀░░█░░░░▄▀░░░░█░░▄▀░░░░░░░░░░█░░▄▀░░░░░░▄▀░░█
█░░▄▀▄▀▄▀▄▀▄▀▄▀░░███████░░▄▀░░██████████░░▄▀░░░░░░▄▀░░░░░░▄▀░░█░░▄▀▄▀▄▀░░█░░▄▀▄▀▄▀▄▀▄▀░░█░░▄▀▄▀▄▀▄▀▄▀░░█
█░░░░░░░░░░░░░░░░███████░░░░░░██████████░░░░░░██░░░░░░██░░░░░░█░░░░░░░░░░█░░░░░░░░░░░░░░█░░░░░░░░░░░░░░█
████████████████████████████████████████████████████████████████████████████████████████████████████████
```
Amanuense · by wilo (Wilmer Buestan)
