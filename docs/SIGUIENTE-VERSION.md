# 🎯 Siguiente versión — Amanuense v0.4.0

**Versión actual:** v0.3.0 (13-oct-2026) · en producción en `wilo-server` con Tailscale y API key.
**Meta de la v0.4:** que la app sea confiable en clases reales, aunque no haya señal, y que las notas lleguen solas a la bóveda.

---

## 1. Cola de pendientes (prioridad alta)
Hoy, si no hay conexión al terminar la grabación, se puede "Reintentar", pero si cierras la app el pendiente se pierde (el audio sigue guardado en la app).

- [ ] Guardar cada grabación pendiente en disco (audio + título + materia + ⭐ + duración).
- [ ] Sección **Pendientes** en la app con el estado de cada una (en cola / enviando / error).
- [ ] Reintento automático al abrir la app y cuando vuelva la conexión.
- [ ] Botón para reintentar o descartar a mano.
- [ ] Aviso en la notificación: "2 grabaciones esperando conexión".

**Listo cuando:** grabas en modo avión, cierras la app y, al volver la señal, la nota aparece sola.

## 2. Syncthing: celular ↔ bóveda (prioridad alta)
- [ ] Instalar **Syncthing-Fork** en el celular y `syncthing` en la laptop.
- [ ] Sincronizar `Documents/Cerebro_wilo` (celular) ↔ `~/Documentos/Cerebro_wilo` (laptop).
- [ ] Excluir `Cerebro_wilo_audios` y `.obsidian/workspace*` para evitar conflictos.
- [ ] Probar: grabar en el celular → la nota aparece en Obsidian de la laptop.

**Listo cuando:** una clase grabada en el celular aparece en Obsidian de la PC sin tocar nada.

## 3. Modelo `medium` (prioridad media)
- [ ] En `wilo-server`: `WHISPER_MODEL=medium` → `docker compose up -d`.
- [ ] Transcribir la misma clase de 10+ min con `small` y con `medium`; comparar tiempo y errores.
- [ ] Quedarse con `medium` si tarda menos de la mitad de lo que dura el audio.
- [ ] Anotar los resultados en `docs/DEPLOY-UBUNTU.md`.

## 4. Mejoras pequeñas
- [ ] **Importar audio** desde la app (FLAC de Linux, audios de WhatsApp, grabaciones viejas).
- [ ] **Editar la nota** en la app para corregir errores de Whisper (también sirve para entrenar después).
- [ ] Mostrar en la notificación cuánto lleva grabando y cuántas ⭐.
- [ ] Copia de seguridad del `.env` del server (fuera del repo).

---

## Ideas para versiones futuras
| Idea | Versión |
|---|---|
| Horario de clases → notificación "¿Grabar Evolución?" con la materia ya elegida | v0.5 |
| Skill de Claude Code que cree resumen, puntos clave y tareas de cada clase en la bóveda | v0.5 |
| Botón en ajustes rápidos de Android para grabar sin abrir la app | v0.5 |
| Nota que junte los ⭐ de una materia para estudiar antes del examen | v0.5 |
| Bloques de ~30 s con texto en vivo mientras graba | v0.6 |
| Separar voces (Persona 1, Persona 2…) con pyannote — necesita cuenta de Hugging Face | v0.6 |
| Entrenar Whisper con los audios guardados + notas corregidas (necesita GPU) | v1.x |
| Modo invitado / comercial (transcripción en el dispositivo, aviso de grabación LOPDP, Play Store) | v1.x |

---

## Cómo publicar la v0.4
1. Cambiar `version:` en `app/pubspec.yaml` a `0.4.0+4` y `appVersion` en `app/lib/theme.dart`.
2. `flutter test` y `flutter analyze` sin errores.
3. `flutter build apk --release --split-per-abi` → instalar `app-arm64-v8a-release.apk` en el celular.
4. En `wilo-server`: `cd ~/amanuense && git pull && cd server && docker compose up -d --build`.
5. `git tag -a v0.4.0` + `git push --tags`, y registrar la sesión en Cerebro_wilo.

---
Amanuense · by wilo (Wilmer Buestan)
