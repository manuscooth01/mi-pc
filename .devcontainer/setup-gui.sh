#!/bin/bash
set -e
sudo apt-get update
sudo apt-get install -y dbus-x11 xfce4 xfce4-goodies xrdp

echo "xfce4-session" > ~/.xsession
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

mkdir -p ~/MisArchivos