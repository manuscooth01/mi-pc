#!/bin/bash
# setup-sunshine.sh - Instala Sunshine para Moonlight
set -e

echo "=== Instalando Sunshine para Moonlight ==="

# Dependencias base
sudo apt-get update || true
sudo apt-get install -y --no-install-recommends \
  libva2 libvdpau1 libpulse0 libx11-6 libxrandr2 libxcb1 libssl3 \
  curl wget tigervnc-standalone-server tigervnc-common tightvncpasswd || true

# Configurar VNC headless (necesario para display X)
mkdir -p ~/.vnc
echo "12345678" | tightvncpasswd -f > ~/.vnc/passwd || true
chmod 600 ~/.vnc/passwd || true

cat > ~/.vnc/xstartup << 'EOF'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=XFCE
export XDG_SESSION_DESKTOP=XFCE
[ -r $HOME/.Xresources ] && xrdb $HOME/.Xresources
exec dbus-launch --exit-with-session startxfce4
EOF
chmod +x ~/.vnc/xstartup

cat > ~/.vnc/config << 'EOF'
geometry=1280x720
depth=24
localhost=no
EOF

# Iniciar VNC en :1
vncserver -kill :1 2>/dev/null || true
rm -rf /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true
vncserver :1 -geometry 1280x720 -depth 24 -localhost no
sleep 2

# Instalar Sunshine si no existe
if ! command -v sunshine &> /dev/null; then
  echo "Instalando Sunshine..."
  
  SUNSHINE_VERSION=$(curl -fsSL --max-time 10 https://api.github.com/repos/LizardByte/Sunshine/releases/latest 2>/dev/null | grep '"tag_name"' | head -1 | cut -d '"' -f 4 || echo "")
  
  if [ -n "$SUNSHINE_VERSION" ]; then
    echo "Version detectada: $SUNSHINE_VERSION"
    SUNSHINE_URL="https://github.com/LizardByte/Sunshine/releases/download/${SUNSHINE_VERSION}/sunshine_$(echo ${SUNSHINE_VERSION} | sed 's/^v//')-1%2Bubuntu22.04_amd64.deb"
  else
    echo "Usando version fallback..."
    SUNSHINE_URL="https://github.com/LizardByte/Sunshine/releases/download/v2026.906.222525/sunshine_2026.906.222525-1%2Bubuntu22.04_amd64.deb"
  fi
  
  echo "Descargando desde: $SUNSHINE_URL"
  
  if curl -L --max-time 120 -o /tmp/sunshine.deb "$SUNSHINE_URL"; then
    sudo dpkg -i /tmp/sunshine.deb || {
      sudo apt-get install -f -y || true
      sudo dpkg -i /tmp/sunshine.deb || { echo "FALLO la instalacion de Sunshine."; exit 1; }
    }
    rm -f /tmp/sunshine.deb
    echo "Sunshine instalado correctamente."
  else
    echo "FALLO la descarga de Sunshine."
    exit 1
  fi
fi

# Configurar Sunshine
export DISPLAY=:1
SUNSHINE_CONFIG_DIR="$HOME/.config/sunshine"
mkdir -p "$SUNSHINE_CONFIG_DIR"

if [ ! -f "$SUNSHINE_CONFIG_DIR/sunshine.conf" ]; then
  cat > "$SUNSHINE_CONFIG_DIR/sunshine.conf" << 'CONF'
port = 47990
origin_web_ui_allowed = *
system_tray = false
CONF
fi

if [ ! -f "$SUNSHINE_CONFIG_DIR/accounts.json" ]; then
  cat > "$SUNSHINE_CONFIG_DIR/accounts.json" << 'CREDS'
{
  "creds": [
    {
      "username": "codespace",
      "password": "codespace"
    }
  ]
}
CREDS
fi

# Script de inicio Sunshine
cat > ~/start-sunshine.sh << 'EOS'
#!/bin/bash
export DISPLAY=:1

# Asegurar VNC activo
if ! pgrep -x Xtigervnc >/dev/null 2>&1; then
  vncserver -kill :1 2>/dev/null || true
  rm -rf /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true
  vncserver :1 -geometry 1280x720 -depth 24 -localhost no
  sleep 2
fi

pkill sunshine 2>/dev/null || true
sleep 1

echo "=== Sunshine para Moonlight ==="
echo "Streaming: puerto 47990"
echo "Web UI: https://localhost:47991 (codespace/codespace)"
echo ""
echo "Moonlight en celular:"
echo "  1. tailscale up (mismo login)"
echo "  2. tailscale ip -4"
echo "  3. Moonlight > Add Host > IP"
echo "  4. Pair con PIN en Web UI"
echo ""

nohup sunshine > /tmp/sunshine.log 2>&1 &
SUNSHINE_PID=$!
echo "Sunshine PID: $SUNSHINE_PID"

# Esperar a que Sunshine este listo
for i in $(seq 1 30); do
  if curl -k -fsS --max-time 3 https://127.0.0.1:47991 >/dev/null 2>&1; then
    echo "Sunshine listo en https://localhost:47991"
    break
  fi
  if ! kill -0 $SUNSHINE_PID 2>/dev/null; then
    echo "Sunshine se detuvo. Revisa /tmp/sunshine.log"
    tail -20 /tmp/sunshine.log 2>/dev/null
    exit 1
  fi
  sleep 1
done
EOS
chmod +x ~/start-sunshine.sh

# Script de inicio Tailscale (para Codespaces con feature)
cat > ~/start-tailscale.sh << 'EOS'
#!/bin/bash
# Tailscale en Codespaces con feature ya instalado

echo "=== Conectando Tailscale ==="

# En Codespaces, tailscaled ya corre como servicio
# Solo necesitamos hacer 'up'

if [ -n "$TAILSCALE_AUTH_KEY" ]; then
  echo "Usando TAILSCALE_AUTH_KEY..."
  sudo tailscale up --authkey="$TAILSCALE_AUTH_KEY" --hostname=codespace-${CODESPACE_NAME:-gui}
elif [ -n "$1" ]; then
  echo "Usando auth key proporcionada..."
  sudo tailscale up --authkey="$1" --hostname=codespace-${CODESPACE_NAME:-gui}
else
  echo "Login interactivo (abrir link en navegador/celular):"
  sudo tailscale up --hostname=codespace-${CODESPACE_NAME:-gui}
fi

echo ""
echo "Esperando IP..."
sleep 3
tailscale ip -4
EOS
chmod +x ~/start-tailscale.sh

# Aliases
cat >> ~/.bashrc << 'ALIASES'

# Moonlight
alias moonlight='~/start-sunshine.sh'
alias moonlog='tail -f /tmp/sunshine.log'
alias ts='~/start-tailscale.sh'
alias tsip='tailscale ip -4'
ALIASES
source ~/.bashrc 2>/dev/null || true

echo ""
echo "=========================================="
echo "  SUNSHINE + TAILSCALE LISTO (Codespaces)"
echo "=========================================="
echo ""
echo "COMANDOS:"
echo "  moonlight        -> inicia Sunshine"
echo "  moonlog          -> ver logs"
echo "  ts [auth-key]    -> conecta Tailscale"
echo "  tsip             -> IP para Moonlight"
echo ""
echo "EN CODESPACES:"
echo "  1. Agrega secret TAILSCALE_AUTH_KEY (opcional)"
echo "  2. Ejecuta: ts"
echo "  3. Ejecuta: tsip"
echo "  4. Usa esa IP en Moonlight app"
echo ""
echo "CREDENCIALES SUNSHINE: codespace / codespace"
echo "PASS VNC: 12345678"
echo "=========================================="