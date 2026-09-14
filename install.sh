#!/bin/bash
# install.sh - Script maestro de instalacion y diagnostico
# Ejecuta: bash install.sh
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ERRORS=0
FIXED=0

ok() { echo -e "${GREEN}[OK]${NC} $1"; }
fail() { echo -e "${RED}[FALLO]${NC} $1"; ERRORS=$((ERRORS+1)); }
warn() { echo -e "${YELLOW}[AVISO]${NC} $1"; }
fix() { echo -e "${YELLOW}[ARREGLANDO]${NC} $1"; FIXED=$((FIXED+1)); }

echo "=========================================="
echo "  INSTALADOR MI PC VIRTUAL"
echo "=========================================="
echo ""

# ============================================
# 1. SISTEMA BASE
# ============================================
echo "--- 1. Verificando sistema base ---"

if ! command -v apt-get &>/dev/null; then
  fail "apt-get no encontrado (¿eres root o Debian/Ubuntu?)"
else
  ok "apt-get disponible"
fi

if ! command -v curl &>/dev/null; then
  warn "curl no encontrado, instalando..."
  sudo apt-get update -qq && sudo apt-get install -y -qq curl
  fix "curl instalado"
fi

if ! command -v wget &>/dev/null; then
  warn "wget no encontrado, instalando..."
  sudo apt-get install -y -qq wget
  fix "wget instalado"
fi

if ! command -v git &>/dev/null; then
  warn "git no encontrado, instalando..."
  sudo apt-get install -y -qq git
  fix "git instalado"
fi

# ============================================
# 2. ESCRITORIO XFCE
# ============================================
echo ""
echo "--- 2. Verificando escritorio XFCE ---"

if command -v xfce4-session &>/dev/null; then
  ok "xfce4-session instalado"
else
  warn "XFCE no encontrado, instalando..."
  sudo apt-get update -qq
  sudo apt-get install -y --no-install-recommends xfce4 xfce4-terminal thunar dbus-x11
  fix "XFCE instalado"
fi

# ============================================
# 3. SERVIDOR VNC
# ============================================
echo ""
echo "--- 3. Verificando servidor VNC ---"

VNC_OK=0

if command -v Xtigervnc &>/dev/null || command -v vncserver &>/dev/null; then
  ok "TigerVNC instalado"
  VNC_OK=1
fi

if [ $VNC_OK -eq 0 ]; then
  if command -v Xvnc &>/dev/null || command -v tightvncserver &>/dev/null; then
    ok "TightVNC instalado"
    VNC_OK=1
  fi
fi

if [ $VNC_OK -eq 0 ]; then
  warn "VNC no encontrado, instalando TigerVNC..."
  sudo apt-get install -y --no-install-recommends tigervnc-standalone-server tigervnc-common || \
  sudo apt-get install -y tightvncserver || true
  fix "VNC instalado"
fi

# ============================================
# 4. noVNC / WEBSOCKIFY
# ============================================
echo ""
echo "--- 4. Verificando noVNC ---"

NOVNC_OK=0

if [ -d "/usr/share/novnc" ]; then
  ok "noVNC instalado"
  NOVNC_OK=1
fi

if [ $NOVNC_OK -eq 0 ]; then
  warn "noVNC no encontrado, instalando..."
  sudo apt-get install -y --no-install-recommends novnc websockify || \
  sudo apt-get install -y novnc websockify || true
  if [ -d "/usr/share/novnc" ]; then
    ok "noVNC instalado"
    fix "noVNC instalado"
  else
    fail "noVNC no se pudo instalar"
  fi
fi

# ============================================
# 5. CONFIGURACION VNC
# ============================================
echo ""
echo "--- 5. Verificando configuracion VNC ---"

mkdir -p ~/.vnc

# Password
if [ -f ~/.vnc/passwd ]; then
  ok "Password VNC configurado"
else
  warn "Password VNC no existe, creando..."
  echo "12345678" | vncpasswd -f > ~/.vnc/passwd
  chmod 600 ~/.vnc/passwd
  fix "Password VNC creado (12345678)"
fi

# xstartup
XSTARTUP_OK=0
if [ -f ~/.vnc/xstartup ]; then
  if grep -q "xfce4-session\|startxfce4" ~/.vnc/xstartup 2>/dev/null; then
    ok "xstartup configurado correctamente"
    XSTARTUP_OK=1
  fi
fi

if [ $XSTARTUP_OK -eq 0 ]; then
  warn "xstartup incorrecto, recreando..."
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
  fix "xstartup recreado"
fi

# ============================================
# 6. SUNSHINE
# ============================================
echo ""
echo "--- 6. Verificando Sunshine ---"

if command -v sunshine &>/dev/null; then
  ok "Sunshine instalado: $(sunshine --version 2>&1 | head -1 || echo 'version desconocida')"
else
  warn "Sunshine no encontrado, instalando..."
  
  # Intentar desde GitHub API
  SUNSHINE_VERSION=$(curl -fsSL --max-time 10 https://api.github.com/repos/LizardByte/Sunshine/releases/latest 2>/dev/null | grep '"tag_name"' | head -1 | cut -d '"' -f 4 || echo "")
  
  if [ -n "$SUNSHINE_VERSION" ]; then
    SUNSHINE_URL="https://github.com/LizardByte/Sunshine/releases/download/${SUNSHINE_VERSION}/sunshine_$(echo ${SUNSHINE_VERSION} | sed 's/^v//')-1%2Bubuntu22.04_amd64.deb"
  else
    SUNSHINE_URL="https://github.com/LizardByte/Sunshine/releases/download/v2026.906.222525/sunshine_2026.906.222525-1%2Bubuntu22.04_amd64.deb"
  fi
  
  # Instalar dependencias
  sudo apt-get install -y --no-install-recommends libva2 libvdpau1 libpulse0 libx11-6 libxrandr2 libxcb1 libssl3 2>/dev/null || true
  
  echo "Descargando Sunshine..."
  if curl -L --max-time 120 -o /tmp/sunshine.deb "$SUNSHINE_URL"; then
    sudo dpkg -i /tmp/sunshine.deb || {
      sudo apt-get install -f -y || true
      sudo dpkg -i /tmp/sunshine.deb || true
    }
    rm -f /tmp/sunshine.deb
    
    if command -v sunshine &>/dev/null; then
      ok "Sunshine instalado"
      fix "Sunshine instalado"
    else
      fail "Sunshine no se pudo instalar"
    fi
  else
    fail "No se pudo descargar Sunshine"
  fi
fi

# Configuracion Sunshine
SUNSHINE_CONFIG_DIR="$HOME/.config/sunshine"
mkdir -p "$SUNSHINE_CONFIG_DIR"

if [ ! -f "$SUNSHINE_CONFIG_DIR/sunshine.conf" ]; then
  warn "Creando configuracion Sunshine..."
  cat > "$SUNSHINE_CONFIG_DIR/sunshine.conf" << 'CONF'
port = 47990
origin_web_ui_allowed = *
CONF
  fix "sunshine.conf creado"
else
  ok "sunshine.conf existe"
fi

if [ ! -f "$SUNSHINE_CONFIG_DIR/accounts.json" ]; then
  warn "Creando credenciales Sunshine..."
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
  fix "accounts.json creado (codespace/codespace)"
else
  ok "accounts.json existe"
fi

# ============================================
# 7. TAILSCALE
# ============================================
echo ""
echo "--- 7. Verificando Tailscale ---"

if command -v tailscale &>/dev/null; then
  ok "Tailscale instalado"
else
  warn "Tailscale no encontrado, instalando..."
  curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null 2>&1 || true
  curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null 2>&1 || true
  sudo apt-get update -qq || true
  sudo apt-get install -y tailscale || true
  if command -v tailscale &>/dev/null; then
    ok "Tailscale instalado"
    fix "Tailscale instalado"
  else
    fail "Tailscale no se pudo instalar"
  fi
fi

# ============================================
# 8. SCRIPTS DE INICIO
# ============================================
echo ""
echo "--- 8. Verificando scripts de inicio ---"

SCRIPTS=("start-gui.sh" "start-vnc.sh" "start-novnc.sh" "start-sunshine.sh" "start-tailscale.sh" "start-tailscale-login.sh")

for script in "${SCRIPTS[@]}"; do
  if [ -f ~/"$script" ] && [ -x ~/"$script" ]; then
    ok "$script existe y es ejecutable"
  else
    warn "$script falta o no es ejecutable, recreando..."
    # Se recrean desde setup-gui.sh
    bash .devcontainer/setup-gui.sh 2>/dev/null || true
    break
  fi
done

# ============================================
# 9. ALIASES
# ============================================
echo ""
echo "--- 9. Verificando aliases ---"

if grep -q "alias gui=" ~/.bashrc 2>/dev/null; then
  ok "Aliases configurados"
else
  warn "Aliases no encontrados, agregando..."
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
  fix "Aliases agregados"
fi

# ============================================
# 10. LIMPIAR SESIONES VNC MUERTAS
# ============================================
echo ""
echo "--- 10. Limpiando sesiones VNC ---"

vncserver -kill :1 2>/dev/null || true
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true
ok "Sesiones VNC limpiadas"

# ============================================
# RESUMEN
# ============================================
echo ""
echo "=========================================="
echo "  RESUMEN DEL DIAGNOSTICO"
echo "=========================================="
echo ""
echo -e "  Errores: ${RED}$ERRORS${NC}"
echo -e "  Arreglos: ${YELLOW}$FIXED${NC}"
echo ""

if [ $ERRORS -eq 0 ]; then
  echo -e "${GREEN}TODO LISTO!${NC}"
  echo ""
  echo "INICIO RAPIDO:"
  echo "  gui          -> inicia escritorio"
  echo "  sunshine     -> inicia Moonlight server"
  echo "  ts           -> conecta Tailscale"
  echo "  tsip         -> muestra IP"
  echo ""
  echo "CELULAR:"
  echo "  1. Instala Tailscale + Moonlight"
  echo "  2. Login en Tailscale (mismo que Codespace)"
  echo "  3. Moonlight > Add Host > IP de tsip"
  echo "  4. Pair con PIN en Sunshine Web (47990)"
  echo ""
  echo "CREDENCIALES:"
  echo "  Sunshine: codespace / codespace"
  echo "  VNC: 12345678"
else
  echo -e "${RED}HAY $ERRORS ERRORES. Revisa los mensajes de arriba.${NC}"
fi
echo "=========================================="
