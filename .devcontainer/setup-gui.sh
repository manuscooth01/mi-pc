#!/bin/bash
set -e
sudo apt-get update
sudo apt-get install -y dbus-x11 xfce4 xfce4-goodies xrdp

sudo usermod -aG ssl-cert xrdp 2>/dev/null || true

RDP_USERNAME="${RDP_USERNAME:-${_REMOTE_USER:-vscode}}"
if [[ -n "${RDP_PASSWORD:-}" ]]; then
	if ! id "$RDP_USERNAME" >/dev/null 2>&1; then
		sudo useradd -m -s /bin/bash "$RDP_USERNAME"
	fi
	printf '%s:%s\n' "$RDP_USERNAME" "$RDP_PASSWORD" | sudo chpasswd
	sudo usermod -aG sudo "$RDP_USERNAME"
else
	echo "AVISO: RDP_PASSWORD no está definido; no se cambia ninguna contraseña."
fi

RDP_HOME=$(getent passwd "$RDP_USERNAME" | cut -d: -f6)
if [[ -n "$RDP_HOME" ]]; then
	printf '%s\n' "xfce4-session" | sudo tee "$RDP_HOME/.xsession" >/dev/null
	sudo chown "$RDP_USERNAME:$RDP_USERNAME" "$RDP_HOME/.xsession"
fi

mkdir -p ~/MisArchivos