# Curso de Acción — Amanuense

**Autor:** Wilmer Buestan · **Fecha:** 2026-10-13

## Misión
App que capture voz (clases y reuniones), la transcriba a texto literal y guarde la nota `.md` en el almacenamiento local (teléfono o PC), con un solo código para Android (APK) y PC.

## Decisiones tomadas
| Tema | Decisión |
|---|---|
| Framework app | **Flutter** (Android + Linux/Windows con un solo código) |
| Transcripción | **faster-whisper** en server Ubuntu propio (FastAPI). Motor intercambiable |
| Modo de escucha | **Sesión continua**: Iniciar al empezar la clase, Detener al final; sigue con pantalla apagada |
| Salida | Texto **literal** en `.md`. La IA se aplica a mano (descargar .md → Claude) y luego se automatiza |
| Conocimiento | Las notas terminan en la bóveda Obsidian **Cerebro** (Syncthing) |
| Futuro | **Modo invitado / comercial**: transcriptor en el dispositivo o nube, sin depender del server propio |

## Arquitectura
```
[App Flutter]  --audio en bloques ~30 s-->  [Ubuntu Server: FastAPI + faster-whisper]
  Android / PC                                     |
     |                                             +--> texto + marcas de tiempo
     +--> guarda .md local --(Syncthing)--> Bóveda Obsidian "Cerebro"
```

## Fases
- [x] **F0** Server transcriptor (FastAPI + faster-whisper, página web, script CLI, servicio systemd)
- [x] **F0.1** Docker (`docker compose`, volumen para el modelo) · marca Amanuense · barra de progreso web
- [x] **F1** App Flutter MVP: grabar → enviar → guardar `.md` · probada en Android 16 (S22 Ultra)
- [ ] **F1.1** Server en la máquina vieja → ver [`DEPLOY-UBUNTU.md`](DEPLOY-UBUNTU.md)
- [x] **F2a** Servicio en primer plano (pantalla apagada) · ⭐ favoritos · materias con vocabulario · notas en la bóveda Cerebro_wilo · ícono
- [x] **F2a+** Interfaz renovada en app y web (menú ☰, animaciones, notas con buscador, historial web, tema oscuro)
- [ ] **F2b** Bloques de ~30 s con texto en vivo y cola offline
- [ ] **F2c** Separar quién habla (Persona 1, Persona 2…)
- [ ] **F2** Sesión larga: bloques, segundo plano (foreground service), cola offline
- [ ] **F3** Seguridad + acceso remoto (API key + Tailscale) + Syncthing a Cerebro
- [ ] **F4** Procesamiento con IA automático (resumen, puntos clave, tareas)
- [ ] **F5** Modo invitado / comercial (motor on-device/nube, aviso de grabación — LOPDP)

## Ideas (backlog)
| Idea | Fase |
|---|---|
| Subir un audio existente desde la app (grabadora de Linux, WhatsApp) | F2 |
| Mantener pantalla y micrófono activos en clases de 2 h (foreground service) | F2 |
| Modelo propio: con los audios guardados + notas corregidas, afinar Whisper (fine-tuning) en GPU | F4 |
| Resumen / puntos clave / tareas con Claude, sin tocar el literal | F4 |
| Ícono propio de la app y APK firmado | F3 |

## Riesgos y medidas
| Riesgo | Medida |
|---|---|
| Android mata la grabación en segundo plano | Foreground service con notificación fija (F2) |
| Sin conexión al server | Audio se guarda completo en el teléfono; bloques en cola (F2) |
| Server expuesto a internet | Solo LAN hasta F3; luego API key + Tailscale, sin abrir puertos |
| Grabar a terceros sin aviso (comercial) | Aviso/consentimiento visible (F5) |
| CPU lento para clases de 1-2 h | Modelo `small` en CPU; `large-v3-turbo` si hay GPU NVIDIA |
