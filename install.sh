#!/bin/bash
# install.sh - Instala Sunshine + Tailscale para Moonlight (Codespaces ready)
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[AVISO]${NC} $1"; }

echo "=========================================="
echo "  INSTALADOR MOONLIGHT (Sunshine)"
echo "=========================================="
echo ""

# Sistema base
warn "Instalando dependencias..."
sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends \
  curl wget libva2 libvdpau1 libpulse0 libx11-6 libxrandr2 libxcb1 libssl3 \
  dbus-x11 xfce4 xfce4-goodies \
  tigervnc-standalone-server tigervnc-common tightvncpasswd
ok "Dependencias instaladas"

# VNC headless
mkdir -p ~/.vnc
echo "12345678" | tightvncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnc/passwd

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

vncserver -kill :1 2>/dev/null || true
rm -rf /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true
vncserver :1 -geometry 1280x720 -depth 24 -localhost no
sleep 2
ok "VNC headless en :1 (5901)"

# Sunshine
if ! command -v sunshine &>/dev/null; then
  warn "Instalando Sunshine..."
  SUNSHINE_VERSION=$(curl -fsSL --max-time 10 https://api.github.com/repos/LizardByte/Sunshine/releases/latest 2>/dev/null | grep '"tag_name"' | head -1 | cut -d '"' -f 4 || echo "")
  
  if [ -n "$SUNSHINE_VERSION" ]; then
    SUNSHINE_URL="https://github.com/LizardByte/Sunshine/releases/download/${SUNSHINE_VERSION}/sunshine_$(echo ${SUNSHINE_VERSION} | sed 's/^v//')-1%2Bubuntu22.04_amd64.deb"
  else
    SUNSHINE_URL="https://github.com/LizardByte/Sunshine/releases/download/v2026.906.222525/sunshine_2026.906.222525-1%2Bubuntu22.04_amd64.deb"
  fi
  
  curl -L --max-time 120 -o /tmp/sunshine.deb "$SUNSHINE_URL"
  sudo dpkg -i /tmp/sunshine.deb || { sudo apt-get install -f -y; sudo dpkg -i /tmp/sunshine.deb; }
  rm -f /tmp/sunshine.deb
  ok "Sunshine instalado"
else
  ok "Sunshine ya instalado"
fi

# Config Sunshine
SUNSHINE_CONFIG_DIR="$HOME/.config/sunshine"
mkdir -p "$SUNSHINE_CONFIG_DIR"

[ ! -f "$SUNSHINE_CONFIG_DIR/sunshine.conf" ] && cat > "$SUNSHINE_CONFIG_DIR/sunshine.conf" << 'CONF'
port = 47990
origin_web_ui_allowed = *
system_tray = false
CONF

[ ! -f "$SUNSHINE_CONFIG_DIR/accounts.json" ] && cat > "$SUNSHINE_CONFIG_DIR/accounts.json" << 'CREDS'
{
  "creds": [{ "username": "codespace", "password": "codespace" }]
}
CREDS
ok "Configuración Sunshine lista"

# Script inicio Sunshine
cat > ~/start-sunshine.sh << 'EOS'
#!/bin/bash
export DISPLAY=:1
if ! pgrep -x Xtigervnc >/dev/null 2>&1; then
  vncserver -kill :1 2>/dev/null || true
  rm -rf /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true
  vncserver :1 -geometry 1280x720 -depth 24 -localhost no
  sleep 2
fi
pkill sunshine 2>/dev/null || true
sleep 1
echo "=== Sunshine para Moonlight ==="
echo "Streaming: 47990"
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
for i in $(seq 1 30); do
  if curl -k -fsS --max-time 3 https://127.0.0.1:47991 >/dev/null 2>&1; then
    echo "Sunshine listo en https://localhost:47991"
    break
  fi
  if ! kill -0 $SUNSHINE_PID 2>/dev/null; then
    echo "Sunshine se detuvo. Ver /tmp/sunshine.log"
    tail -20 /tmp/sunshine.log 2>/dev/null
    exit 1
  fi
  sleep 1
done
EOS
chmod +x ~/start-sunshine.sh
ok "Script start-sunshine.sh creado"

# Script inicio Tailscale (Codespaces)
cat > ~/start-tailscale.sh << 'EOS'
#!/bin/bash
echo "=== Conectando Tailscale ==="
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
ok "Script start-tailscale.sh creado"

# Aliases
grep -q "alias moonlight=" ~/.bashrc || cat >> ~/.bashrc << 'ALIASES'

# Moonlight
alias moonlight='~/start-sunshine.sh'
alias moonlog='tail -f /tmp/sunshine.log'
alias ts='~/start-tailscale.sh'
alias tsip='tailscale ip -4'
ALIASES
ok "Aliases agregados"

# Tailscale (feature en Codespaces, apt en local)
if ! command -v tailscale &>/dev/null; then
  warn "Instalando Tailscale..."
  curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null 2>&1 || true
  curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null 2>&1 || true
  sudo apt-get update -qq || true
  sudo apt-get install -y tailscale || true
  ok "Tailscale instalado"
else
  ok "Tailscale ya disponible"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}INSTALACION COMPLETA${NC}"
echo "=========================================="
echo ""
echo "USO:"
echo "  moonlight        -> inicia Sunshine"
echo "  moonlog          -> ver logs"
echo "  ts [auth-key]    -> conecta Tailscale"
echo "  tsip             -> IP para Moonlight"
echo ""
echo "EN GITHUB CODESPACES:"
echo "  1. Agrega secret TAILSCALE_AUTH_KEY (opcional)"
echo "  2. Ejecuta: ts"
echo "  3. Ejecuta: tsip"
echo "  4. Usa esa IP en Moonlight app"
echo ""
echo "CREDENCIALES:"
echo "  Sunshine Web: codespace / codespace"
echo "  VNC: 12345678"
echo "=========================================="