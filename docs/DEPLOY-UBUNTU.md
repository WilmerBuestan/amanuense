# 🖥️ Llevar Amanuense al Ubuntu Server

Guía paso a paso para dejar el transcriptor funcionando 24/7 en la máquina vieja
(i7, 16 GB RAM) y usarlo desde el celular, en casa y fuera de casa.

> **¿Hay que comprar algo?** No. Para uso personal no hace falta dominio, IP pública
> ni abrir puertos en el router: en casa se usa la IP local y fuera de casa
> **Tailscale** (gratis). Un dominio (~10–15 USD/año) solo tendría sentido en la
> F5, si Amanuense se ofrece a otras personas.

---

## 0. Antes de empezar
- Ubuntu Server 24.04 o más nuevo instalado, con usuario `sudo`.
- El server conectado al mismo router que el celular (de preferencia por **cable**).
- Desde la laptop debes poder entrar por SSH: `ssh usuario@IP_SERVER`.
  ¿No sabes la IP? En el server: `ip -4 addr | grep inet`.

## 1. Dejarle una IP fija al server
Si la IP cambia, la app deja de encontrarlo. Hay dos formas:

**Opción A (recomendada): reservar la IP en el router.**
Entra al router (normalmente `http://192.168.100.1` o `192.168.1.1`), busca
*DHCP → Reserva de IP / Static lease*, elige el server por su MAC y fija una IP,
por ejemplo `192.168.100.50`. Reinicia el server.

**Opción B: IP fija en Ubuntu (netplan).**
```bash
ip -4 route | grep default          # anota la puerta de enlace (gateway) y la interfaz (ej. enp3s0)
sudo nano /etc/netplan/50-cloud-init.yaml
```
```yaml
network:
  version: 2
  ethernets:
    enp3s0:                       # tu interfaz
      dhcp4: false
      addresses: [192.168.100.50/24]
      routes: [{to: default, via: 192.168.100.1}]   # tu gateway
      nameservers: {addresses: [1.1.1.1, 8.8.8.8]}
```
```bash
sudo netplan apply
```

En el resto de la guía, `IP_SERVER` = esa IP fija.

## 2. Preparar Ubuntu e instalar Docker
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y git curl unattended-upgrades     # actualizaciones de seguridad automáticas
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
exit                                                 # sal y vuelve a entrar por SSH
docker --version                                     # debe responder sin sudo
```

## 3. Traer el proyecto
```bash
git clone https://github.com/WilmerBuestan/amanuense.git
cd amanuense/server
```
> Si el repo es **privado**, GitHub te pedirá usuario y un *token* (no tu contraseña):
> GitHub → Settings → Developer settings → Personal access tokens → *Fine-grained*,
> con permiso de solo lectura a `amanuense`.

## 4. Configurar y arrancar
```bash
cp .env.example .env
nano .env
```
Para el i7 de 16 GB:

| Prueba | `WHISPER_MODEL` | Cuándo |
|---|---|---|
| 1ª | `small` | Punto de partida (~1–2 GB RAM) |
| 2ª | `medium` | Si `small` va sobrado: más precisión (~3–5 GB RAM) |
| Plan B | `base` | Si `small` tarda más que la duración del audio |

```bash
docker compose up -d --build
docker compose logs -f          # verás el banner AMANUENSE; espera "Amanuense listo" y sal con Ctrl+C
curl http://localhost:8000/health
```
✅ Debe responder `"status":"ok"`. El contenedor arranca solo cada vez que se prende la máquina.

## 5. Probarlo desde la red de casa
1. En la laptop o el celular abre `http://IP_SERVER:8000`, sube un audio largo (10–60 min)
   y anota cuánto tarda. Regla: **debe tardar menos que la duración del audio**.
2. En la app: ⚙️ → Server = `http://IP_SERVER:8000` → **Probar conexión** → ✅ → Guardar.
3. Graba una nota corta y revisa que aparezca en `Documents/Amanuense`.

Si no conecta, revisa el firewall:
```bash
sudo ufw allow OpenSSH
sudo ufw allow from 192.168.0.0/16 to any port 8000 proto tcp
sudo ufw enable
```
> ⚠️ **No** hagas "abrir puerto / port forwarding" del 8000 en el router.
> El server no debe quedar expuesto a internet.

## 6. Usarlo fuera de casa con Tailscale (gratis)
Tailscale crea una red privada entre tus dispositivos. Nada queda abierto a internet.

**En el server:**
```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up            # abre el enlace que muestra e inicia sesión (Google/GitHub)
tailscale ip -4              # anota la IP 100.x.y.z
```
**En el celular:** instala **Tailscale** desde Play Store e inicia sesión con **la misma cuenta**.
**En la laptop (opcional):** `curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up`.

En el panel de Tailscale (login.tailscale.com → Machines) puedes:
- Renombrar el server a `amanuense`.
- Activar **MagicDNS** (DNS → Enable) para usar un nombre en vez de la IP.
- En el server: *⋯ → Disable key expiry* para que no se desconecte cada 6 meses.

En la app pon como server **`http://amanuense:8000`** (con MagicDNS) o
`http://100.x.y.z:8000`. Funciona en casa y fuera, con Tailscale encendido en el celular.

## 7. Activar la API key
Aunque solo lo uses tú, ponle clave antes de usar Tailscale:
```bash
openssl rand -hex 24          # copia el resultado
nano .env                     # API_KEY=<pega aquí>
docker compose up -d
```
En la app: ⚙️ → **Probar conexión**. Como el server pide clave, aparece el campo
**API key**: pégala → Guardar. La página web también mostrará el campo solo.

## 8. Que las notas lleguen solas a Obsidian (Syncthing)
1. Celular: instala **Syncthing-Fork** (F-Droid o Play Store).
2. PC donde está la bóveda Cerebro: `sudo apt install syncthing` y abre `http://127.0.0.1:8384`.
3. Vincula los dos dispositivos (cada uno muestra un *Device ID* / QR).
4. En el celular comparte la carpeta `Documents/Amanuense`. En la PC acéptala y
   ponle como destino `…/Cerebro/Amanuense`.
5. Graba una nota → en segundos aparece en Obsidian.

## 9. Actualizar a una versión nueva
```bash
cd ~/amanuense && git pull
cd server && docker compose up -d --build
```
El modelo descargado se conserva (volumen `modelos`).

## 10. Mantenimiento
| Para… | Comando |
|---|---|
| Ver logs | `docker compose logs -f --tail 50` |
| Reiniciar | `docker compose restart` |
| Detener | `docker compose down` |
| Cambiar modelo | editar `.env` → `docker compose up -d` |
| Uso de CPU/RAM | `docker stats amanuense` |
| Liberar espacio | `docker image prune -f` |

## Problemas comunes
| Síntoma | Causa / solución |
|---|---|
| `curl: Connection reset` justo al arrancar | Está descargando el modelo; mira `docker compose logs -f` |
| Error 422 al transcribir | Audio dañado o formato raro. El mensaje dice el motivo |
| La app no conecta en casa | IP cambió (paso 1), firewall (paso 5) o el celular no está en el Wi-Fi |
| La app no conecta fuera | Tailscale apagado en el celular o el server sin sesión (`tailscale status`) |
| Error 401 | Falta o está mal la API key en la app |
| Muy lento | Bajar a `base`, o revisar `docker stats` por si otra cosa usa la CPU |

---
Amanuense · by wilo (Wilmer Buestan)
