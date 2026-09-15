#!/bin/bash
set -e
sudo service xrdp restart
if [[ -n "${TS_AUTHKEY:-}" ]]; then
	sudo tailscale up --authkey="$TS_AUTHKEY" --accept-routes --hostname="codespace-pc" --ssh
	echo "=== IP de Tailscale ==="
	tailscale ip -4
else
	echo "AVISO: TS_AUTHKEY no está definido; XRDP queda iniciado sin conectar Tailscale."
fi