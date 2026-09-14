#!/bin/bash
# recovery-fix.sh - Ejecutar ESTO AHORA en recovery mode para arreglar sin rebuild
echo "=== FIX RECOVERY MODE - Ejecutando ahora ==="
cd /workspaces/mi-pc || cd /home/vscode || true

sudo apt-get update
sudo apt-get install -y xfce4 xfce4-terminal dbus-x11 tigervnc-standalone-server tigervnc-common novnc websockify || sudo apt-get install -y tightvncserver novnc websockify

mkdir -p ~/.vnc
echo "12345678" | vncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnc/passwd

cat > ~/.vnc/xstartup << 'EOF'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=XFCE
export XDG_SESSION_DESKTOP=XFCE
dbus-launch --exit-with-session startxfce4 &
EOF
chmod +x ~/.vnc/xstartup

# Crear scripts
bash .devcontainer/setup-gui.sh || true

echo "=== Iniciando GUI ahora ==="
vncserver -kill :1 2>/dev/null; rm -rf /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null; true
vncserver :1 -geometry 1280x720 -depth 24 -localhost no
sleep 2
pkill -f websockify 2>/dev/null; true
websockify --web=/usr/share/novnc 6080 localhost:5901 &
sleep 1

echo ""
echo "GUI INICIADA"
echo "Ve a pestaña PUERTOS > 6080 > click Abrir en navegador"
echo "Password: 12345678"
echo ""
echo "Para Moonlight:"
echo "  ~/start-sunshine.sh"
echo "  ~/start-tailscale.sh"
echo "  tailscale ip -4"
