# 📱 Guía: Interfaz Gráfica Codespace en Celular

Tienes 3 formas de ver el escritorio Linux desde tu celular.

---

## 🚀 INICIO RÁPIDO (en Codespace)

Abre una terminal en tu Codespace y ejecuta:

```bash
~/start-gui.sh
```

Esto inicia:
- **VNC** en puerto 5901
- **noVNC** (web) en puerto 6080

---

## OPCIÓN 1: NAVEGADOR (Más fácil, sin instalar nada) ⭐ RECOMENDADA

Funciona en cualquier celular, solo necesitas Chrome/Safari.

1. En Codespace:
```bash
~/start-gui.sh
```

2. En la pestaña **PORTS** de VS Code (abajo), busca `noVNC Web 6080` y click en el icono de 🌐 para abrir en navegador.

   O abre manualmente:
   ```
   https://TU-CODESPACE-NOMBRE-6080.app.github.dev/vnc.html
   ```

3. En tu celular:
   - Click **Connect**
   - Password: `12345678`
   - Ya ves XFCE completo

**Ventaja:** No necesitas instalar Tailscale ni apps.

---

## OPCIÓN 2: RVNC VIEWER / RealVNC Viewer / AVNC (App VNC)

Mucho más fluido que navegador, ideal para celular.

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

1. **Instala Tailscale** (Play Store / App Store) y loguéate con la misma cuenta.
2. **Instala una de estas apps:**
   - **RealVNC Viewer** (oficial, gratis)
   - **RVNC Viewer** (ligero)
   - **AVNC** (Android, open source, muy bueno)
   - **bVNC**

3. **Nueva conexión:**
   - **Address / Host:** `100.91.180.66:5901` (la IP que te dio Tailscale)
   - **Name:** Codespace
   - **Password:** `12345678`

4. **Conectar** - Verás XFCE. Puedes cambiar resolución:
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

## OPCIÓN 3: MOONLIGHT (Más fluido, 60fps, ideal para juegos/apps)

Moonlight es mucho más rápido que VNC porque usa Sunshine (codificación por hardware/software optimizada).

### En Codespace:

```bash
~/start-gui.sh
~/start-tailscale.sh tskey-xxxxx
~/start-sunshine.sh
```

Esto abre Sunshine en `http://localhost:47990`

1. En Codespace, abre en navegador:
   ```
   https://TU-CODESPACE-47990.app.github.dev/
   ```
   O haz port forward de 47990 y abre `http://localhost:47990`

2. Te pedirá crear usuario/password para Sunshine la primera vez. Créalo.

### En tu Celular:

1. **Tailscale** instalado y conectado (misma red que Codespace).
2. **Instala Moonlight:**
   - Android: Play Store > Moonlight Game Streaming
   - iOS: App Store > Moonlight

3. **Agregar Host Manualmente:**
   - Abre Moonlight > Pulsa `+` o `Add Host Manually`
   - IP: `100.91.180.66` (tu IP Tailscale del Codespace, SIN puerto)
   - Te mostrará un PIN de 4 dígitos, ej: `1234`

4. **En Codespace (navegador Sunshine):**
   - Ve a `http://localhost:47990` > Tab **PIN** > Ingresa el PIN de Moonlight > Pair

5. **Listo:** Te aparecerá `Desktop` en Moonlight. Tócalo y verás XFCE a 60fps.

**Config Sunshine:** `~/.config/sunshine/sunshine.conf`
- Ya está en modo software (sin GPU, compatible con Codespace)
- Puedes subir fps: `fps = 60`

**Puertos Sunshine que deben estar abiertos:**
- 47984/tcp, 47989/tcp, 47990/tcp, 48010/tcp
- 47998-48000/udp

Si no conecta, abre todos en Tailscale (ya están permitidos por defecto).

---

## 📐 Resoluciones recomendadas para celular

```bash
# Vertical (celular en mano)
vncserver -kill :1 && vncserver :1 -geometry 720x1280

# Horizontal
vncserver -kill :1 && vncserver :1 -geometry 1280x720

# Tablet
vncserver -kill :1 && vncserver :1 -geometry 1920x1080
```

---

## 🔧 Comandos útiles

```bash
~/start-gui.sh       # Inicia VNC + noVNC
~/start-vnc.sh       # Solo VNC
~/start-novnc.sh     # Solo noVNC web
~/start-sunshine.sh  # Sunshine para Moonlight
~/start-tailscale.sh tskey-xxx  # Conectar Tailscale
vncserver -list      # Ver sesiones
vncserver -kill :1   # Matar sesión
vncpasswd            # Cambiar password VNC
tailscale ip -4      # Ver tu IP
```

---

## ❓ ¿Cuál usar?

- **Solo probar rápido:** Opción 1 (navegador, noVNC)
- **Uso diario celular:** Opción 2 (RVNC Viewer + Tailscale) - balance fluidez/fácil
- **Máxima fluidez/juegos:** Opción 3 (Moonlight + Sunshine + Tailscale)

---

## ⚠️ Notas Codespaces

- El Codespace se apaga tras 30 min inactivo por defecto. Ve a Settings > Codespaces > Timeout.
- Sin Tailscale, el VNC directo por `app.github.dev` NO funciona con apps VNC nativas (solo noVNC web), porque GitHub usa HTTPS y VNC necesita TCP crudo. Por eso Tailscale es obligatorio para RVNC Viewer y Moonlight.
- Moonlight sin GPU usa CPU, puede tener lag pero sigue siendo mejor que VNC.
