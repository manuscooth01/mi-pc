#!/bin/bash
# setup-sunshine.sh - Instala Sunshine para Moonlight (sin GUI)
set -e

echo "=== Instalando Sunshine para Moonlight ==="

# Dependencias base
sudo apt-get update || true
sudo apt-get install -y --no-install-recommends \
  libva2 libvdpau1 libpulse0 libx11-6 libxrandr2 libxcb1 libssl3 \
  curl wget tigervnc-standalone-server tigervnc-common || true

# Configurar VNC headless (necesario para display X)
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

# Script de inicio
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

pkill -f sunshine 2>/dev/null || true
sleep 1

echo "=== Sunshine para Moonlight ==="
echo "Streaming: puerto 47990"
echo "Web UI: https://localhost:47991 (codespace/codespace)"
echo ""
echo "Moonlight en celular:"
echo "  1. Conecta Tailscale (mismo login)"
echo "  2. IP: tailscale ip -4"
echo "  3. Moonlight > Add Host > IP (sin puerto)"
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

# Alias
cat >> ~/.bashrc << 'ALIASES'

# Aliases - Moonlight
alias moonlight='~/start-sunshine.sh'
alias moonlog='tail -f /tmp/sunshine.log'
ALIASES
source ~/.bashrc 2>/dev/null || true

# Tailscale
if ! command -v tailscale &> /dev/null; then
  echo "Instalando Tailscale..."
  curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null || true
  curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null || true
  sudo apt-get update || true
  sudo apt-get install -y tailscale || true
fi

echo ""
echo "=========================================="
echo "  SUNSHINE + TAILSCALE LISTO"
echo "=========================================="
echo ""
echo "COMANDOS:"
echo "  moonlight    -> inicia Sunshine"
echo "  moonlog      -> ver logs"
echo "  tailscale up -> conectar VPN"
echo "  tailscale ip -4  -> ver IP para Moonlight"
echo ""
echo "CREDENCIALES SUNSHINE: codespace / codespace"
echo "PASS VNC: 12345678"
echo "=========================================="