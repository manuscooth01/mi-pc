#!/bin/bash
# setup-gui.sh - GUI ligera + VNC + noVNC + Tailscale + Sunshine Moonlight
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
websockify --web=/usr/share/novnc 6080 localhost:5901 &
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
if command -v tailscale &>/dev/null; then
  TS_IP=$(tailscale ip -4 2>/dev/null || echo "")
  if [ -n "$TS_IP" ]; then
    echo "  IP: $TS_IP -> RVNC Viewer $TS_IP:5901"
  else
    echo "  Ejecuta: ~/start-tailscale.sh  (te dara link de login)"
  fi
else
  echo "  Tailscale no instalado. Ejecuta: ~/start-tailscale.sh"
fi
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
websockify --web=/usr/share/novnc 6080 localhost:5901 &
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
  echo "Se abrira un link de autenticacion. Abrelo en tu celular/navegador y logueate."
  echo ""
  sudo tailscale --socket=/tmp/tailscaled.sock up --hostname=codespace-gui-${CODESPACE_NAME:-gui} 2>&1 || sudo tailscale up --hostname=codespace-gui 2>&1 || true
  echo ""
  echo "Si arriba viste un link tipo https://login.tailscale.com/a/xxxxxxxx"
  echo "Abrelo en tu celular/navegador y autoriza."
  echo ""
  echo "Despues de autorizar, ejecuta: tailscale ip -4"
fi

echo ""
echo "Esperando IP..."
sleep 2
tailscale --socket=/tmp/tailscaled.sock ip -4 2>/dev/null || tailscale ip -4 2>/dev/null || echo "Aun sin IP. Si usaste link, autoriza el link de arriba y luego ejecuta: tailscale ip -4"
echo ""
EOS

cat > ~/start-tailscale-login.sh << 'EOS'
#!/bin/bash
# Solo link, sin key - el mas facil
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
echo "Despues de abrir el link y loguearte:"
echo "  tailscale ip -4"
echo "Esa IP la usas en RVNC Viewer y Moonlight"
EOS

cat > ~/start-sunshine.sh << 'EOS'
#!/bin/bash
# start-sunshine.sh - Instala y ejecuta Sunshine para Moonlight

echo "=== Sunshine para Moonlight ==="

# Verificar que VNC este activo (Sunshine necesita un display X)
if ! pgrep -x Xvnc >/dev/null 2>&1 && ! pgrep -x Xtigervnc >/dev/null 2>&1 && ! pgrep -x vncserver >/dev/null 2>&1; then
  echo "No se detecta VNC activo; iniciando VNC en :1..."
  vncserver :1 -geometry 1280x720 -depth 24 -localhost no 2>/dev/null || true
  sleep 2
fi

# Instalar Sunshine si no existe
if ! command -v sunshine &> /dev/null; then
  echo "Instalando Sunshine..."
  
  # Intentar obtener version desde GitHub API
  SUNSHINE_VERSION=$(curl -fsSL --max-time 10 https://api.github.com/repos/LizardByte/Sunshine/releases/latest 2>/dev/null | grep '"tag_name"' | head -1 | cut -d '"' -f 4 || echo "")
  
  if [ -n "$SUNSHINE_VERSION" ]; then
    echo "Version detectada: $SUNSHINE_VERSION"
    SUNSHINE_URL="https://github.com/LizardByte/Sunshine/releases/download/${SUNSHINE_VERSION}/sunshine_$(echo ${SUNSHINE_VERSION} | sed 's/^v//')-1+ubuntu22.04_amd64.deb"
  else
    # URL directa como fallback (version verificada)
    echo "No se pudo obtener version desde API, usando URL directa..."
    SUNSHINE_URL="https://github.com/LizardByte/Sunshine/releases/download/v2026.906.222525/sunshine_2026.906.222525-1+ubuntu22.04_amd64.deb"
  fi
  
  echo "Descargando desde: $SUNSHINE_URL"
  echo "Esto puede tardar 1-2 minutos..."
  
  # Instalar dependencias necesarias primero
  sudo apt-get install -y --no-install-recommends wget libva2 libvdpau1 libpulse0 libx11-6 libxrandr2 libxcb1 libssl3 2>/dev/null || true
  
  if wget --timeout=60 -O /tmp/sunshine.deb "$SUNSHINE_URL"; then
    echo "Descarga completa. Instalando..."
    sudo dpkg -i /tmp/sunshine.deb || {
      echo "Error en dpkg, instalando dependencias..."
      sudo apt-get install -f -y || true
      sudo dpkg -i /tmp/sunshine.deb || { echo "FALLO la instalacion de Sunshine."; exit 1; }
    }
    rm -f /tmp/sunshine.deb
    echo "Sunshine instalado correctamente."
  else
    echo "FALLO la descarga de Sunshine."
    echo "URL: $SUNSHINE_URL"
    exit 1
  fi
fi

# Configurar Sunshine
export DISPLAY=:1
SUNSHINE_CONFIG_DIR="$HOME/.config/sunshine"
mkdir -p "$SUNSHINE_CONFIG_DIR"

# Crear configuracion si no existe
if [ ! -f "$SUNSHINE_CONFIG_DIR/sunshine.conf" ]; then
  cat > "$SUNSHINE_CONFIG_DIR/sunshine.conf" << 'CONF'
port = 47990
origin_web_ui_allowed = *
CONF
fi

# Crear credenciales si no existen
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
  echo "Credenciales Sunshine: usuario=codespace, password=codespace"
fi

# Matar Sunshine previo
pkill -f sunshine 2>/dev/null || true
sleep 1

echo ""
echo "=========================================="
echo "  SUNSHINE INICIANDO"
echo "=========================================="
echo "Web UI: Puertos > 47990 > Abrir en navegador"
echo "Credenciales: codespace / codespace"
echo ""
echo "Moonlight celular:"
echo "  1. Conecta Tailscale: ~/start-tailscale.sh"
echo "  2. IP: tailscale ip -4"
echo "  3. Moonlight > Add Host > IP (sin puerto)"
echo "  4. PIN > Sunshine Web > PIN > Pair"
echo "=========================================="
echo ""

# Ejecutar Sunshine en background
nohup sunshine > /tmp/sunshine.log 2>&1 &
SUNSHINE_PID=$!
echo "Sunshine PID: $SUNSHINE_PID"

# Esperar a que Sunshine este listo
echo "Esperando a que Sunshine responda..."
for i in $(seq 1 30); do
  if curl -k -fsS --max-time 3 https://127.0.0.1:47990 >/dev/null 2>&1; then
    echo "Sunshine listo en https://127.0.0.1:47990"
    break
  fi
  if ! kill -0 $SUNSHINE_PID 2>/dev/null; then
    echo "Sunshine se detuvo. Revisa /tmp/sunshine.log"
    tail -20 /tmp/sunshine.log 2>/dev/null
    exit 1
  fi
  sleep 1
done

if ! curl -k -fsS --max-time 5 https://127.0.0.1:47990 >/dev/null 2>&1; then
  echo "Advertencia: Sunshine no responde aun en 47990"
  echo "Logs: /tmp/sunshine.log"
fi
EOS

chmod +x ~/start-*.sh

echo "=== Configurando alias ==="
cat >> ~/.bashrc << 'ALIASES'

# Aliases - Mi PC Virtual
alias gui='~/start-gui.sh'
alias vnc='~/start-vnc.sh'
alias novnc='~/start-novnc.sh'
alias sunshine='~/start-sunshine.sh'
alias ts='~/start-tailscale.sh'
alias tslogin='~/start-tailscale-login.sh'
alias tsip='tailscale ip -4'
alias vc='vncserver -list'
alias vk='vncserver -kill :1'
ALIASES
source ~/.bashrc 2>/dev/null || true

echo "=== Instalando Tailscale ==="
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
echo ""
echo "ALIASES (escribe estos comandos):"
echo "  gui          -> inicia escritorio VNC+noVNC"
echo "  sunshine     -> inicia Sunshine para Moonlight"
echo "  ts           -> conecta Tailscale"
echo "  tsip         -> muestra IP de Tailscale"
echo "  tslogin      -> login Tailscale sin API key"
echo "  vnc          -> solo VNC"
echo "  novnc        -> solo noVNC web"
echo "  vc           -> listar sesiones VNC"
echo "  vk           -> matar sesion VNC"
echo ""
echo "CELULAR:"
echo "  1. Instala Tailscale + Moonlight"
echo "  2. Conecta Tailscale (mismo login)"
echo "  3. Moonlight > Add Host > IP de tailscale"
echo "  4. Pair con PIN en Sunshine Web"
echo ""
echo "CREDENCIALES SUNSHINE: codespace / codespace"
echo "PASS VNC: 12345678"
echo "=========================================="
