#!/bin/bash
# setup-gui.sh - Instala escritorio gráfico + VNC + Tailscale en Codespaces

set -e

echo "=== [1/5] Instalando escritorio XFCE... ==="
sudo apt-get update
sudo apt-get install -y xfce4 xfce4-goodies xfce4-terminal thunar mousepad ristretto
sudo apt-get install -y xorg dbus-x11 x11-xserver-utils x11vnc xvfb
sudo apt-get install -y websocky novnc

echo "=== [2/5] Configurando VNC... ==="
mkdir -p ~/.vnc
cat > ~/.vnc/xstartup << 'EOF'
#!/bin/bash
export DISPLAY=:1
export XDG_SESSION_DESKTOP=XFCE
export XDG_CURRENT_DESKTOP=XFCE
export XDG_SESSION_TYPE=x11
dbus-launch --exit-with-session xfce4-session &
EOF
chmod +x ~/.vnc/xstartup

echo "=== [3/5] Configurando noVNC (acceso web)... ==="
sudo ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/vnc_lite.html
cat > ~/.vnc/config << 'EOF'
geometry=1920x1080
depth=24
localhost=no
EOF

echo "=== [4/5] Instalando Tailscale... ==="
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null
sudo apt-get update
sudo apt-get install -y tailscale
sudo systemctl enable tailscaled
sudo systemctl start tailscaled

echo "=== [5/5] Instalando apps útiles... ==="
sudo apt-get install -y firefox chromium-browser libreoffice gimp vlc file-roller
sudo apt-get install -y build-essential cmake git wget curl unzip
sudo apt-get install -y nodejs npm python3-pip

echo ""
echo "=========================================="
echo "  ESCRITORIO GRÁFICO INSTALADO"
echo "=========================================="
echo ""
echo "PARA INICIAR:"
echo "  1. Iniciar VNC:    vncserver -geometry 1920x1080 -depth 24"
echo "  2. Iniciar noVNC:  websocky run localhost:6080 --daemon"
echo "  3. Iniciar Tailscale:"
echo "     sudo tailscale up --authkey=TSKEY --hostname=codespace-gui"
echo ""
echo "PARA CONECTARSE:"
echo "  - VNC Client:  localhost:5901"
echo "  - noVNC Web:   https://PORT-forwarding-url (puerto 6080)"
echo "  - Tailscale:   IP del codespace (puerto 5901)"
echo ""
echo "CONTRASEÑA VNC (establecer con: vncpasswd):"
echo "  Por defecto no tiene contraseña. Ejecuta 'vncpasswd' para configurarla."
echo "=========================================="
