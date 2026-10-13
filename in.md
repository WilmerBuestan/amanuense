# 🎙️ Amanuense — Estado del proyecto
Autor: Wilmer Buestan · Fecha: 13-oct-2026
mi maquina vieja es una core i7 con 16gb de 8 de RAM y pueso aumentarle sin problema la ram

## Misión
Desarrollar una aplicación que capture voz en clases y reuniones, la transcriba
a texto literal y guarde la nota en formato .md en el almacenamiento local
(teléfono o PC), con un solo código para Android (APK) y PC. Las notas terminan
en la bóveda Obsidian "Cerebro".

## Decisiones tomadas
- App: Flutter (Android + PC con un mismo código).
- Transcripción: faster-whisper (Whisper offline) en un servidor propio:
  la máquina vieja con Ubuntu Server, desplegado en Docker.
- Modo de escucha: sesión continua. Iniciar al empezar la clase y Detener
  al terminar; sigue grabando con la pantalla apagada.
- Salida: texto literal en .md. El procesamiento con IA se hace primero a mano
  (descargar el .md y pasarlo a Claude) y luego se automatiza.
- Motor intercambiable: hoy el server propio; a futuro on-device o nube para
  un modo invitado / versión comercial.
- Seguridad: el server solo en LAN; luego API key + Tailscale, sin abrir puertos.

## Arquitectura
[App Flutter] --audio en bloques ~30 s--> [Ubuntu Server (Docker): FastAPI + faster-whisper]
     |                                              |
     |                                              +--> texto + marcas de tiempo
     +--> guarda .md local --(Syncthing)--> Bóveda Obsidian "Cerebro"

## Lo que ya está hecho (F0 – Server transcriptor) ✅
Carpeta: ~/Desktop/proyectos_wilo/Grabador de voz
- API en FastAPI:
  - GET  /health          → estado, modelo, CPU/GPU
  - POST /transcribe      → JSON con texto, duración y segmentos con tiempos
  - POST /transcribe/md   → devuelve la nota .md lista para descargar
  - /docs                 → documentación interactiva (Swagger)
- Motor faster-whisper con detección automática de GPU/CPU y filtro de silencios.
- Generador de la nota .md: encabezado YAML (título, fecha, duración, tags,
  estado: literal) + transcripción en párrafos con marcas de tiempo [mm:ss].
- Nombre de archivo: AAAA-MM-DD_HHMM_titulo.md
- Página web: desde el celular se sube un audio y se descarga el .md.
- Script de terminal transcribir.sh (audio → .md).
- Scripts de instalación, arranque y servicio systemd.
- API key opcional (header X-API-Key) y límite de tamaño de archivo.
- 6 pruebas automáticas que pasan.
- Documentación: README.md y docs/CA.md.
- Pendiente de verificar: la transcripción con el modelo real en el server.

## Hecho el 13-oct-2026 ✅
F0.1 – Docker + marca
  - Dockerfile + docker-compose.yml (restart automático, volumen para el modelo).
  - Probado en la laptop: 23,7 s de audio → 1,7 s de proceso (modelo small, CPU).
  - Arreglo: av==14.2.0 (faster-whisper 1.2 no funciona con PyAV 15+).
  - Nombre oficial: Amanuense. Banner + firma "by wilo" en server, script, web, README y pie del .md.
  - Web: barra de progreso estimada que aprende la velocidad del server, botón Descargar .md,
    API key oculta salvo que el server la exija.

F1 – App Flutter MVP (carpeta app/)
  - Grabar / Detener, envío al server, guardado del .md en Documents/Amanuense.
  - Configuración (server, carpeta, API key solo si hace falta), lista de notas, ver/copiar nota,
    Reintentar si falla. Probada en el S22 Ultra (Android 16).

F2a – Clases largas y Cerebro (13-oct-2026)
  - Servicio en primer plano: graba con pantalla apagada; notificación con ⭐ Marcar y ⏹ Detener.
  - ⭐ Favoritos → sección "Momentos importantes" y párrafos marcados en el .md.
  - Materias con carpeta en la bóveda (VIII Semestre/<materia>) y vocabulario para Whisper.
  - Frontmatter con tipo/estado/tags/creado y enlace [[materia]] (reglas de Cerebro_wilo).
  - Opción "Guardar los audios" (fuera de la bóveda) para entrenar un modelo propio después.
  - Ícono propio (app y página web).

Interfaz v0.3 (13-oct-2026)
  - App: menú hamburguesa con Salir, botón de grabar con pulso, onda de voz, chips de materia, estado del server,
    pantalla Notas (buscar/filtrar), nota con formato y Compartir, Acerca de. Colores del ícono.
  - Web: menú lateral, arrastrar archivo, etapas + tiempo restante, vista con formato, historial, tema oscuro.

## Lo que viene
F1.1 – Llevar el server a la máquina vieja (guía: docs/DEPLOY-UBUNTU.md)
  - IP fija, Docker, modelo small→medium, medir con un audio de clase real.


F2 – Sesiones largas (clases y reuniones)
  - Grabación en segundo plano con notificación fija (foreground service).
  - Envío por bloques de ~30 s; el .md se va armando en vivo.
  - El audio completo se guarda en el teléfono; si no hay conexión, los bloques
    quedan en cola y se transcriben después.

F3 – Seguridad, acceso remoto y Cerebro
  - API key obligatoria + Tailscale para llegar al server desde cualquier lugar.
  - Syncthing para que los .md caigan solos en la bóveda Obsidian.
  - Versión de la app para PC (Linux).

F4 – IA automática
  - Botón "Procesar": resumen, puntos clave, acuerdos y tareas sobre la
    transcripción literal (se conserva siempre el texto original).

F5 – Modo invitado / comercial
  - Transcripción on-device o en la nube, sin depender del server propio.
  - Aviso y consentimiento de grabación (LOPDP Ecuador).
  - Publicación en Play Store.

## Riesgos y medidas
- Android mata la grabación en segundo plano → foreground service (F2).
- Sin conexión al server → cola offline + audio guardado completo (F2).
- La máquina vieja es lenta → modelo liviano + procesamiento por bloques.
- Server expuesto a internet → solo LAN hasta F3; luego Tailscale + API key.
- Grabar a terceros sin aviso → aviso visible obligatorio en la versión comercial (F5).