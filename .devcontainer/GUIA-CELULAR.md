# Guia: Interfaz Grafica Codespace en Celular

Tienes 3 formas de ver el escritorio Linux desde tu celular.

---

## INICIO RAPIDO (en Codespace)

Abre una terminal en tu Codespace y ejecuta:

```bash
~/start-gui.sh
```

Esto inicia:
- **VNC** en puerto 5901
- **noVNC** (web) en puerto 6080

---

## OPCION 1: NAVEGADOR (Mas facil, sin instalar nada) RECOMENDADA

Funciona en cualquier celular, solo necesitas Chrome/Safari.

1. En Codespace:
```bash
~/start-gui.sh
```

2. En la pestana **PORTS** de VS Code (abajo), busca `noVNC Web 6080` y click en el icono de globito para abrir en navegador.

   O abre manualmente:
   ```
   https://TU-CODESPACE-NOMBRE-6080.app.github.dev
   ```

3. En tu celular:
   - Click **Connect**
   - Password: `12345678`
   - Ya ves XFCE completo

**Ventaja:** No necesitas instalar nada mas.

---

## OPCION 2: RVNC VIEWER / RealVNC Viewer / AVNC (App VNC)

Mucho mas fluido que navegador, ideal para celular.

### En Codespace:

```bash
# 1. Inicia GUI
~/start-gui.sh

# 2. Inicia Tailscale (necesitas tu Auth Key)
~/start-tailscale.sh tskey-auth-xxxxxx-xxxxx

# O si guardaste la key en Secrets:
sudo tailscale up --authkey=$TAILSCALE_AUTH_KEY --hostname=codespace-gui

# 3. Mira tu IP
tailscale ip -4
# Ejemplo: 100.91.180.66
```

Consigue tu Auth Key en: https://login.tailscale.com/admin/settings/keys
Crea una **Reusable + Ephemeral**.

### En tu Celular:

1. **Instala Tailscale** (Play Store / App Store) y logueate con la misma cuenta.
2. **Instala una de estas apps:**
   - **RealVNC Viewer** (oficial, gratis)
   - **RVNC Viewer** (ligero)
   - **AVNC** (Android, open source, muy bueno)
   - **bVNC**

3. **Nueva conexion:**
   - **Address / Host:** `100.91.180.66:5901` (la IP que te dio Tailscale)
   - **Name:** Codespace
   - **Password:** `12345678`

4. **Conectar** - Veras XFCE. Puedes cambiar resolucion:
```bash
vncserver -kill :1
vncserver :1 -geometry 720x1280 -depth 24  # vertical para celular
# o 1280x720 horizontal
```

**Cambiar password:**
```bash
vncpasswd
```

---

## OPCION 3: MOONLIGHT (Mas fluido, 60fps, ideal para juegos/apps)

Moonlight es mucho mas rapido que VNC porque usa Sunshine (codificacion por hardware/software optimizada).

### Requisitos en tu Celular:

1. **Tailscale** instalado y logueado (misma red que Codespace)
2. **Moonlight** instalado:
   - Android: Play Store > Moonlight Game Streaming
   - iOS: App Store > Moonlight

### En Codespace:

```bash
# 1. Inicia el escritorio
~/start-gui.sh

# 2. Conecta Tailscale (si no lo hiciste)
~/start-tailscale.sh
# O con API key:
~/start-tailscale.sh tskey-auth-xxxxx

# 3. Inicia Sunshine
~/start-sunshine.sh
```

### Configurar Sunshine:

1. En Codespace, abre la pestana **PORTS** y busca `Sunshine Pair 47990`
2. Click en el icono de globito para abrir `https://TU-CODESPACE-47990.app.github.dev`
3. Te pedira crear usuario/password. Crea uno (ej: `codespace`/`codespace`)

### En tu Celular (Moonlight):

1. Abre Moonlight
2. Pulsa `+` o **Add Host Manually**
3. Escribe la IP de Tailscale (sin puerto): `100.91.180.66`
4. Te mostrara un PIN de 4 digitos, ej: `1234`

5. En Codespace (navegador Sunshine):
   - Ve a `https://TU-CODESPACE-47990.app.github.dev`
   - Tab **PIN**
   - Ingresa el PIN de Moonlight
   - Click **Pair**

6. Listo: Te aparecera `Desktop` en Moonlight. Tocalo y veras XFCE a 60fps.

### Puertos Sunshine (deben estar abiertos en Tailscale):

- 47984/tcp (RTSP)
- 47989/tcp (Web UI)
- 47990/tcp (Pairing)
- 48010/tcp (Control)
- 47998-48000/udp (Video/Audio streaming)

Si no conecta, verifica que Tailscale este activo y que los puertos no esten bloqueados.

---

## Resoluciones recomendadas para celular

```bash
# Vertical (celular en mano)
vncserver -kill :1 && vncserver :1 -geometry 720x1280

# Horizontal
vncserver -kill :1 && vncserver :1 -geometry 1280x720

# Tablet
vncserver -kill :1 && vncserver :1 -geometry 1920x1080
```

---

## Comandos utiles

```bash
~/start-gui.sh       # Inicia VNC + noVNC
~/start-vnc.sh       # Solo VNC
~/start-novnc.sh     # Solo noVNC web
~/start-sunshine.sh  # Sunshine para Moonlight
~/start-tailscale.sh tskey-xxx  # Conectar Tailscale
vncserver -list      # Ver sesiones
vncserver -kill :1   # Matar sesion
vncpasswd            # Cambiar password VNC
tailscale ip -4      # Ver tu IP
```

---

## Cual usar?

- **Solo probar rapido:** Opcion 1 (navegador, noVNC)
- **Uso diario celular:** Opcion 2 (RVNC Viewer + Tailscale) - balance fluidez/facil
- **Maxima fluidez/juegos:** Opcion 3 (Moonlight + Sunshine + Tailscale)

---

## Notas Codespaces

- El Codespace se apaga tras 30 min inactivo por defecto. Ve a Settings > Codespaces > Timeout.
- Sin Tailscale, el VNC directo por `app.github.dev` NO funciona con apps VNC nativas (solo noVNC web), porque GitHub usa HTTPS y VNC necesita TCP crudo. Por eso Tailscale es obligatorio para RVNC Viewer y Moonlight.
- Moonlight sin GPU usa CPU, puede tener lag pero sigue siendo mejor que VNC.
- Sunshine en Codespaces corre en modo software (sin GPU dedicada). Puede ser suficiente para escritorio y apps basicas.
