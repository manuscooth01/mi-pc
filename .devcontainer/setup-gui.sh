#!/bin/bash
# setup-gui.sh - GUI ligera + VNC + noVNC + Tailscale con LOGIN LINK + Sunshine Moonlight
set -e

echo "=== Instalando GUI ligera (XFCE + VNC + noVNC) ==="
sudo apt-get update || true
sudo apt-get install -y --no-install-recommends \
  xfce4 xfce4-terminal thunar dbus-x11 \
  xorg x11-xserver-utils \
  tigervnc-standalone-server tigervnc-common \
  novnc websockify net-tools curl wget || \
sudo apt-get install -y tightvncserver novnc websockify || true

echo "=== Configurando VNC ==="
mkdir -p ~/.vnc
echo "12345678" | vncpasswd -f > ~/.vnc/passwd || true
chmod 600 ~/.vnc/passwd || true

cat > ~/.vnc/xstartup << 'EOF'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=XFCE
export XDG_SESSION_DESKTOP=XFCE
[ -r $HOME/.Xresources ] && xrdb $HOME/.Xresources
dbus-launch --exit-with-session startxfce4 &
EOF
chmod +x ~/.vnc/xstartup

cat > ~/.vnc/config << 'EOF'
geometry=1280x720
depth=24
localhost=no
EOF

sudo chown -R vscode:vscode ~/.vnc 2>/dev/null || true

echo "=== Creando scripts de inicio ==="

cat > ~/start-gui.sh << 'EOS'
#!/bin/bash
echo "=== Iniciando GUI ==="
vncserver -kill :1 2>/dev/null || true
rm -rf /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true
vncserver :1 -geometry 1280x720 -depth 24 -localhost no || tightvncserver :1 -geometry 1280x720 -depth 24 || echo "Error VNC"
sleep 2
pkill -f websockify 2>/dev/null || true
websockify --web=/usr/share/novnc -D 6080 localhost:5901 2>/dev/null || nohup websockify --web=/usr/share/novnc 6080 localhost:5901 > /tmp/novnc.log 2>&1 &
sleep 1
echo ""
echo "=========================================="
echo "  GUI INICIADA"
echo "=========================================="
echo "noVNC Web (navegador celular, sin Tailscale):"
echo "  Puerto 6080 -> Puertos > 6080 > Abrir"
echo "  Pass: 12345678"
echo ""
echo "VNC directo / Moonlight (con Tailscale):"
tailscale ip -4 2>/dev/null && echo "  IP: $(tailscale ip -4) -> RVNC Viewer $(tailscale ip -4):5901" || echo "  Ejecuta: ~/start-tailscale.sh  (te dara link de login)"
echo "=========================================="
EOS

cat > ~/start-vnc.sh << 'EOS'
#!/bin/bash
vncserver -kill :1 2>/dev/null; rm -rf /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null; true
vncserver :1 -geometry 1280x720 -depth 24 -localhost no
echo "VNC en 5901 pass 12345678"
EOS

cat > ~/start-novnc.sh << 'EOS'
#!/bin/bash
pkill -f websockify 2>/dev/null; true
websockify --web=/usr/share/novnc -D 6080 localhost:5901 --daemon
echo "noVNC en 6080 - Abre en Puertos > 6080"
EOS

cat > ~/start-tailscale.sh << 'EOS'
#!/bin/bash
# Soporta 2 modos:
# 1. Con API key: ~/start-tailscale.sh tskey-auth-xxx
# 2. Con link de login (sin key): ~/start-tailscale.sh  -> te da URL https://login.tailscale.com/a/xxxx

# Iniciar daemon si no corre (sin systemd)
if ! pgrep -x tailscaled > /dev/null; then
  echo "Iniciando tailscaled..."
  sudo rm -rf /tmp/tailscaled.sock /tmp/tailscaled.state 2>/dev/null; true
  sudo tailscaled --state=/tmp/tailscaled.state --socket=/tmp/tailscaled.sock > /tmp/tailscaled.log 2>&1 &
  sleep 3
fi

if [ -n "$1" ]; then
  KEY=$1
  echo "Conectando con API Key..."
  sudo tailscale --socket=/tmp/tailscaled.sock up --authkey=$KEY --hostname=codespace-gui-${CODESPACE_NAME:-gui} 2>&1 || sudo tailscale up --authkey=$KEY --hostname=codespace-gui 2>&1
elif [ -n "$TAILSCALE_AUTH_KEY" ]; then
  echo "Conectando con TAILSCALE_AUTH_KEY de env..."
  sudo tailscale --socket=/tmp/tailscaled.sock up --authkey=$TAILSCALE_AUTH_KEY --hostname=codespace-gui-${CODESPACE_NAME:-gui} 2>&1 || sudo tailscale up --authkey=$TAILSCALE_AUTH_KEY --hostname=codespace-gui 2>&1
else
  echo ""
  echo "=== TAILSCALE LOGIN CON LINK (sin API key) ==="
  echo "Se abrirá un link de autenticación. Ábrelo en tu celular/navegador y loguéate."
  echo ""
  # Intentar login interactivo que da link
  sudo tailscale --socket=/tmp/tailscaled.sock up --hostname=codespace-gui-${CODESPACE_NAME:-gui} 2>&1 || sudo tailscale up --hostname=codespace-gui 2>&1 || true
  echo ""
  echo "Si arriba viste un link tipo https://login.tailscale.com/a/xxxxxxxx"
  echo "Ábrelo en tu celular/navegador y autoriza."
  echo ""
  echo "Después de autorizar, ejecuta: tailscale ip -4"
fi

echo ""
echo "Esperando IP..."
sleep 2
tailscale --socket=/tmp/tailscaled.sock ip -4 2>/dev/null || tailscale ip -4 2>/dev/null || echo "Aún sin IP. Si usaste link, autoriza el link de arriba y luego ejecuta: tailscale ip -4"
echo ""
EOS

cat > ~/start-tailscale-login.sh << 'EOS'
#!/bin/bash
# Solo link, sin key - el más fácil
echo "=== TAILSCALE LOGIN CON LINK ==="
if ! pgrep -x tailscaled > /dev/null; then
  sudo rm -rf /tmp/tailscaled.sock /tmp/tailscaled.state 2>/dev/null; true
  sudo tailscaled --state=/tmp/tailscaled.state --socket=/tmp/tailscaled.sock > /tmp/tailscaled.log 2>&1 &
  sleep 3
fi
echo "Abre este link en tu navegador/celular para autenticar:"
echo ""
sudo tailscale --socket=/tmp/tailscaled.sock up --hostname=codespace-gui 2>&1 | tee /tmp/ts-login.txt
cat /tmp/ts-login.txt
echo ""
echo "Después de abrir el link y loguearte:"
echo "  tailscale ip -4"
echo "Esa IP la usas en RVNC Viewer y Moonlight"
EOS

cat > ~/start-sunshine.sh << 'EOS'
#!/bin/bash
set -Eeuo pipefail

echo "=== Sunshine para Moonlight ==="

# Verifica que la herramienta exista antes de seguir.
if ! command -v sunshine &> /dev/null; then
  echo "Instalando Sunshine..."
  SUNSHINE_URL=$(curl -fsSL https://api.github.com/repos/LizardByte/Sunshine/releases/latest | grep "browser_download_url.*ubuntu-22.04.*amd64.deb" | cut -d '"' -f 4 | head -n1)
  if [ -n "$SUNSHINE_URL" ]; then
    wget -q -O /tmp/sunshine.deb "$SUNSHINE_URL" && sudo apt-get install -y /tmp/sunshine.deb || sudo dpkg -i /tmp/sunshine.deb || true
  else
    echo "No se pudo descargar Sunshine. Usa VNC."
    exit 1
  fi
fi

# Seguridad básica del entorno.
export DISPLAY=:1
if [[ -z "${DISPLAY:-}" ]]; then
  echo "ERROR: DISPLAY no está definido."
  exit 1
fi

# Asegura que el escritorio remoto esté disponible antes de abrir Sunshine.
if ! pgrep -x Xvnc >/dev/null 2>&1 && ! pgrep -x Xtigervnc >/dev/null 2>&1 && ! pgrep -x vncserver >/dev/null 2>&1; then
  echo "No se detecta VNC activo; iniciando VNC en :1..."
  vncserver :1 -geometry 1280x720 -depth 24 -localhost no 2>/dev/null || true
fi

# Espera a que VNC escuche en 5901 antes de arrancar la UI.
for i in $(seq 1 20); do
  if ss -lnt | grep -Eq ':5901\s'; then
    break
  fi
  sleep 1
done

if ! ss -lnt | grep -Eq ':5901\s'; then
  echo "ERROR: El servidor VNC no está escuchando en 5901."
  echo "Revisa que la sesión X esté activa y que el puerto 5901 no esté bloqueado."
  exit 1
fi

# Prepara log para diagnóstico si Sunshine no responde.
LOG_FILE="$HOME/.cache/sunshine.log"
mkdir -p "$(dirname "$LOG_FILE")"
: > "$LOG_FILE"

echo "Sunshine Web: Puertos > 47990 > Abrir"
echo "Moonlight celular: Add Host -> IP Tailscale (sin puerto)"
echo "Te pedirá PIN, ponlo en Sunshine Web > PIN"

echo "Comprobando si la interfaz web responde en https://127.0.0.1:47990 ..."
for i in $(seq 1 30); do
  if curl -k -fsS --max-time 3 https://127.0.0.1:47990 >/dev/null 2>&1; then
    echo "Sunshine respondió correctamente en https://127.0.0.1:47990"
    break
  fi
  sleep 1
done

if ! curl -k -fsS --max-time 5 https://127.0.0.1:47990 >/dev/null 2>&1; then
  echo "Advertencia: la interfaz web de Sunshine aún no responde en https://127.0.0.1:47990"
  echo "Verifica que Tailscale esté activo para exponer 47990 y que el puerto no esté bloqueado."
  echo "Diagnóstico rápido: ss -lnt | grep 47990"
  echo "Si hace falta, vuelve a ejecutar este script tras iniciar Tailscale."
fi

# Ejecuta Sunshine con salida capturada para diagnosticar fallos reales.
sunshine 2>&1 | tee "$LOG_FILE"
EOS

chmod +x ~/start-*.sh

echo "=== Instalando Tailscale ==="
if ! command -v tailscale &> /dev/null; then
  curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null || true
  curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null || true
  sudo apt-get update || true
  sudo apt-get install -y tailscale || true
fi

echo ""
echo "=========================================="
echo "  INSTALADO OK - LOGIN CON LINK"
echo "=========================================="
echo "Para GUI: ~/start-gui.sh"
echo "Para Tailscale SIN API KEY (con link):"
echo "  ~/start-tailscale-login.sh"
echo "  Te dará un link https://login.tailscale.com/a/xxxx"
echo "  Ábrelo en tu celular y autoriza"
echo "  Luego: tailscale ip -4"
echo ""
echo "Con API key (si la tienes):"
echo "  ~/start-tailscale.sh tskey-xxx"
echo "=========================================="
