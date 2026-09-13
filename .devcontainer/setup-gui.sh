#!/bin/bash
# setup-gui.sh - Versión ligera y compatible con recovery mode
set -e

echo "=== Instalando GUI ligera (XFCE + VNC + noVNC) ==="

# No fallar si apt tiene warnings
sudo apt-get update || true
sudo apt-get install -y --no-install-recommends \
  xfce4 xfce4-terminal thunar dbus-x11 \
  xorg x11-xserver-utils \
  tigervnc-standalone-server tigervnc-common \
  novnc websockify net-tools curl wget || \
sudo apt-get install -y tightvncserver novnc websockify || true

echo "=== Configurando VNC ==="
mkdir -p ~/.vnc
# Password 12345678
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
sudo chown -R $USER:$USER ~/.vnc 2>/dev/null || true

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
echo "noVNC Web (navegador celular):"
echo "  Puerto 6080 -> Abre en pestaña PUERTOS > 6080 > Abrir en navegador"
echo "  Password: 12345678"
echo ""
echo "VNC directo (RVNC Viewer):"
echo "  Si tienes Tailscale:"
tailscale ip -4 2>/dev/null && echo "  Conecta a: \$(tailscale ip -4):5901" || echo "  Ejecuta: ~/start-tailscale.sh TU_KEY"
echo "  Sin Tailscale: usa noVNC web"
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
websockify --web=/usr/share/novnc -D 6080 localhost:5901
echo "noVNC en 6080"
EOS

cat > ~/start-tailscale.sh << 'EOS'
#!/bin/bash
if [ -z "$1" ] && [ -z "$TAILSCALE_AUTH_KEY" ]; then
  echo "Uso: ~/start-tailscale.sh tskey-auth-xxx"
  echo "o export TAILSCALE_AUTH_KEY=tskey-..."
  exit 1
fi
KEY=${1:-$TAILSCALE_AUTH_KEY}
# Iniciar daemon si no corre (sin systemd)
if ! pgrep -x tailscaled > /dev/null; then
  echo "Iniciando tailscaled sin systemd..."
  sudo tailscaled --state=/tmp/tailscaled.state --socket=/tmp/tailscaled.sock > /tmp/tailscaled.log 2>&1 &
  sleep 3
fi
sudo tailscale --socket=/tmp/tailscaled.sock up --authkey=$KEY --hostname=codespace-gui-${CODESPACE_NAME:-gui} || sudo tailscale up --authkey=$KEY --hostname=codespace-gui || true
echo "IP Tailscale:"
tailscale --socket=/tmp/tailscaled.sock ip -4 2>/dev/null || tailscale ip -4 2>/dev/null || echo "Aun no hay IP, espera 5s y repite tailscale ip -4"
EOS

cat > ~/start-sunshine.sh << 'EOS'
#!/bin/bash
echo "=== Sunshine para Moonlight (experimental sin GPU) ==="
if ! command -v sunshine &> /dev/null; then
  echo "Sunshine no instalado, instalando..."
  SUNSHINE_URL=$(curl -s https://api.github.com/repos/LizardByte/Sunshine/releases/latest | grep "browser_download_url.*ubuntu-22.04.*amd64.deb" | cut -d '"' -f 4 | head -n1)
  if [ -n "$SUNSHINE_URL" ]; then
    wget -q -O /tmp/sunshine.deb "$SUNSHINE_URL" && sudo apt-get install -y /tmp/sunshine.deb || sudo dpkg -i /tmp/sunshine.deb || true
  else
    echo "No se pudo descargar Sunshine. Usa VNC por ahora."
    exit 1
  fi
fi
export DISPLAY=:1
vncserver :1 -geometry 1280x720 -depth 24 -localhost no 2>/dev/null || true
echo "Abre Sunshine Web: http://localhost:47990 o puerto 47990 en PORTS"
echo "En Moonlight celular: Add Host -> IP Tailscale"
sunshine
EOS

chmod +x ~/start-*.sh

echo "=== Instalando Tailscale (sin systemd) ==="
if ! command -v tailscale &> /dev/null; then
  curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null || true
  curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null || true
  sudo apt-get update || true
  sudo apt-get install -y tailscale || true
fi

echo ""
echo "=========================================="
echo "  INSTALADO OK"
echo "=========================================="
echo "Ejecuta: ~/start-gui.sh"
echo "Luego ve a pestaña PUERTOS > 6080 > Abrir"
echo "Pass VNC: 12345678"
echo "=========================================="
