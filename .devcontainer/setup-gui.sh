#!/bin/bash
# setup-gui.sh - Escritorio gráfico + VNC + noVNC + Sunshine (Moonlight) + Tailscale para Codespaces
# Optimizado para celular: RVNC Viewer / RealVNC y Moonlight

set -e

echo "=== [1/6] Instalando escritorio XFCE y dependencias ==="
sudo apt-get update
sudo apt-get install -y xfce4 xfce4-goodies xfce4-terminal thunar mousepad ristretto
sudo apt-get install -y xorg dbus-x11 x11-xserver-utils x11-utils
sudo apt-get install -y xvfb x11vnc
sudo apt-get install -y tigervnc-standalone-server tigervnc-common || sudo apt-get install -y tightvncserver
sudo apt-get install -y novnc websockify net-tools

echo "=== [2/6] Configurando VNC ==="
mkdir -p ~/.vnc
# Password por defecto 12345678 - CAMBIALA con vncpasswd
echo "12345678" | vncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnc/passwd

cat > ~/.vnc/xstartup << 'EOF'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export DISPLAY=:1
export XDG_SESSION_DESKTOP=XFCE
export XDG_CURRENT_DESKTOP=XFCE
export XDG_SESSION_TYPE=x11
export XKL_XMODMAP_DISABLE=1
[ -x /etc/vnc/xstartup ] && exec /etc/vnc/xstartup
[ -r $HOME/.Xresources ] && xrdb $HOME/.Xresources
dbus-launch --exit-with-session startxfce4 &
EOF
chmod +x ~/.vnc/xstartup

cat > ~/.vnc/config << 'EOF'
geometry=1280x720
depth=24
localhost=no
rfbauth=/home/vscode/.vnc/passwd
EOF

# Fix permisos si es root
sudo chown -R vscode:vscode ~/.vnc 2>/dev/null || chown -R $USER:$USER ~/.vnc

echo "=== [3/6] Configurando noVNC (acceso web para celular sin app) ==="
# noVNC ya viene en /usr/share/novnc
sudo mkdir -p /usr/share/novnc

echo "=== [4/6] Instalando Tailscale (para IP directa para RVNC/Moonlight) ==="
if ! command -v tailscale &> /dev/null; then
  curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
  curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null
  sudo apt-get update
  sudo apt-get install -y tailscale
fi
sudo systemctl enable tailscaled 2>/dev/null || true
sudo systemctl start tailscaled 2>/dev/null || sudo tailscaled &

echo "=== [5/6] Instalando Sunshine (servidor para Moonlight) ==="
# Sunshine permite usar Moonlight en el celular - mucho más fluido que VNC
if ! command -v sunshine &> /dev/null; then
  echo "Instalando Sunshine..."
  SUNSHINE_URL=$(curl -s https://api.github.com/repos/LizardByte/Sunshine/releases/latest | grep "browser_download_url.*ubuntu-22.04.*amd64.deb" | cut -d '"' -f 4 | head -n1)
  if [ -n "$SUNSHINE_URL" ]; then
    wget -O /tmp/sunshine.deb "$SUNSHINE_URL" || echo "No se pudo descargar Sunshine, continuando..."
    sudo apt-get install -y /tmp/sunshine.deb || sudo dpkg -i /tmp/sunshine.deb || true
    sudo apt-get install -f -y || true
  else
    echo "No se encontró Sunshine .deb, intentando build..."
    sudo apt-get install -y libavdevice-dev libavfilter-dev libavformat-dev libavcodec-dev libavutil-dev libswscale-dev libssl-dev libx11-dev libxcb-shm0-dev libxcb-xfixes0-dev libxcb1-dev libxcb-randr0-dev libxcb-shape0-dev libxcb-xkb-dev libxcb-xfixes0-dev libasound2-dev libpulse-dev libva-dev libvdpau-dev libwayland-dev libdrm-dev libcap-dev
  fi
fi

# Config Sunshine
mkdir -p ~/.config/sunshine
cat > ~/.config/sunshine/sunshine.conf << 'EOF'
# Sunshine config para Codespace
channels = 1
fps = 60
hevc_mode = 0
av1_mode = 0
capture = x11
encoder = software
origin_pin_allowed = pc
origin_web_ui_allowed = pc
external_ip = 0
lan_encryption_mode = 0
wan_encryption_mode = 0
ping_timeout = 10000
EOF

echo "=== [6/6] Instalando apps útiles y creando scripts de inicio ==="
sudo apt-get install -y firefox chromium-browser libreoffice gimp vlc file-roller 2>/dev/null || true
sudo apt-get install -y build-essential curl wget git unzip 2>/dev/null || true

# Script maestro para iniciar todo
cat > ~/start-gui.sh << 'EOS'
#!/bin/bash
echo "=== Iniciando Escritorio Gráfico Codespace ==="

# Matar sesiones previas
vncserver -kill :1 2>/dev/null || true
pkill -f websockify 2>/dev/null || true
pkill -f sunshine 2>/dev/null || true

# Iniciar VNC
echo "[1/3] Iniciando VNC en :1 (puerto 5901)..."
vncserver :1 -geometry 1280x720 -depth 24 -localhost no 2>/dev/null || tightvncserver :1 -geometry 1280x720 -depth 24 2>/dev/null || echo "VNC ya corriendo"
sleep 2

# Iniciar noVNC (para navegador del celular)
echo "[2/3] Iniciando noVNC en puerto 6080..."
websockify --web=/usr/share/novnc -D 6080 localhost:5901 2>/dev/null || nohup websockify --web=/usr/share/novnc 6080 localhost:5901 > /tmp/novnc.log 2>&1 &
sleep 1

# Mostrar info
echo ""
echo "=========================================="
echo "  ESCRITORIO INICIADO - LISTO PARA CELULAR"
echo "=========================================="
echo ""
CODESPACE_URL=$(echo $CODESPACE_NAME | tr '[:upper:]' '[:lower:]')
if [ -n "$CODESPACE_NAME" ]; then
  echo "OPCION 1 - NAVEGADOR CELULAR (más fácil, sin app):"
  echo "  https://${CODESPACE_NAME}-6080.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}/vnc.html"
  echo "  Password VNC: 12345678 (cambiala con vncpasswd)"
  echo ""
fi
echo "OPCION 2 - RVNC VIEWER / RealVNC Viewer (con Tailscale):"
if command -v tailscale &> /dev/null; then
  TS_IP=$(tailscale ip -4 2>/dev/null | head -n1)
  if [ -n "$TS_IP" ]; then
    echo "  IP Tailscale: $TS_IP"
    echo "  En tu celular (RealVNC Viewer / RVNC Viewer / AVNC):"
    echo "    Host: $TS_IP:5901"
    echo "    Password: 12345678"
  else
    echo "  1. Inicia Tailscale: ~/start-tailscale.sh"
    echo "  2. Luego conecta a IP_TAILSCALE:5901 en tu app VNC"
  fi
else
  echo "  Host: localhost:5901 (necesitas port forward)"
fi
echo ""
echo "OPCION 3 - MOONLIGHT (más fluido, para juegos):"
echo "  1. Inicia Sunshine: ~/start-sunshine.sh"
echo "  2. En Moonlight (celular): Agrega host manualmente -> IP Tailscale"
echo "  3. PIN en Sunshine: http://localhost:47990"
echo ""
echo "Comandos útiles:"
echo "  ~/start-vnc.sh       - Solo VNC"
echo "  ~/start-novnc.sh     - Solo noVNC web"
echo "  ~/start-sunshine.sh  - Sunshine para Moonlight"
echo "  ~/start-tailscale.sh - Conectar Tailscale"
echo "  vncpasswd            - Cambiar password VNC"
echo "=========================================="
EOS

cat > ~/start-vnc.sh << 'EOS'
#!/bin/bash
vncserver -kill :1 2>/dev/null || true
vncserver :1 -geometry 1280x720 -depth 24 -localhost no
echo "VNC iniciado en puerto 5901 - Password: 12345678"
EOS

cat > ~/start-novnc.sh << 'EOS'
#!/bin/bash
pkill -f websockify 2>/dev/null || true
websockify --web=/usr/share/novnc -D 6080 localhost:5901
echo "noVNC iniciado en puerto 6080"
echo "URL: https://${CODESPACE_NAME}-6080.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}/vnc.html"
EOS

cat > ~/start-tailscale.sh << 'EOS'
#!/bin/bash
if [ -z "$1" ]; then
  echo "Uso: ~/start-tailscale.sh TU_AUTH_KEY"
  echo "Consigue tu key en: https://login.tailscale.com/admin/settings/keys"
  echo ""
  echo "Si ya tienes key guardada en secrets, usa:"
  echo "  sudo tailscale up --authkey=\$TAILSCALE_AUTH_KEY --hostname=codespace-gui-\$CODESPACE_NAME"
  exit 1
fi
sudo tailscale up --authkey=$1 --hostname=codespace-gui-${CODESPACE_NAME:-codespace}
echo "Tailscale IP: $(tailscale ip -4)"
EOS

cat > ~/start-sunshine.sh << 'EOS'
#!/bin/bash
echo "=== Iniciando Sunshine para Moonlight ==="
# Asegurar VNC/X11 corriendo
vncserver :1 -geometry 1280x720 -depth 24 -localhost no 2>/dev/null || true
export DISPLAY=:1
# Iniciar Sunshine
echo "Iniciando Sunshine en puerto 47990..."
echo "Abre en tu Codespace: https://${CODESPACE_NAME}-47990.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}/"
echo "O local: http://localhost:47990"
echo ""
echo "En Moonlight celular:"
echo "  1. Instala Tailscale en tu celular y conecta a misma red"
echo "  2. IP Tailscale: $(tailscale ip -4 2>/dev/null)"
echo "  3. Abre Moonlight > Add Host Manually > IP Tailscale"
echo "  4. Te pedirá PIN, ingresalo en http://localhost:47990"
echo ""
sunshine
EOS

chmod +x ~/start-*.sh

echo ""
echo "=========================================="
echo "  ESCRITORIO GRÁFICO INSTALADO CORRECTAMENTE"
echo "=========================================="
echo ""
echo "INICIO RÁPIDO PARA CELULAR:"
echo "  ~/start-gui.sh"
echo ""
echo "GUIA CELULAR:"
echo ""
echo "  RVNC VIEWER / RealVNC / AVNC (Android/iOS):"
echo "    1. En Codespace: ~/start-gui.sh y ~/start-tailscale.sh TU_KEY"
echo "    2. En celular: Instala Tailscale app, logueate misma cuenta"
echo "    3. En celular: Abre RealVNC Viewer > New Connection"
echo "       Address: 100.x.x.x:5901 (IP que te dio Tailscale)"
echo "       Password: 12345678"
echo ""
echo "  NAVEGADOR (sin instalar nada):"
echo "    1. ~/start-gui.sh"
echo "    2. En celular abre: https://TU-CODESPACE-6080.app.github.dev/vnc.html"
echo "    3. Click Connect, password 12345678"
echo ""
echo "  MOONLIGHT (más fluido):"
echo "    1. ~/start-gui.sh && ~/start-sunshine.sh"
echo "    2. Tailscale en Codespace y en celular"
echo "    3. Moonlight > Add Host > IP Tailscale"
echo "    4. PIN en http://localhost:47990"
echo "=========================================="
