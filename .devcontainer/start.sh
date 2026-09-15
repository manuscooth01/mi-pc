#!/bin/bash
sudo service xrdp restart
sudo tailscale up --authkey="$TS_AUTHKEY" --accept-routes --hostname="codespace-pc" --ssh
echo "=== IP de Tailscale ==="
tailscale ip -4