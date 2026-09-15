#!/bin/bash
set -e
sudo apt-get update
sudo apt-get install -y xfce4 xfce4-goodies xrdp

echo "xfce4-session" > ~/.xsession
sudo usermod -aG ssl-cert xrdp 2>/dev/null || true

sudo useradd -m -s /bin/bash "$RDP_USERNAME" 2>/dev/null || true
echo "$RDP_USERNAME:$RDP_PASSWORD" | sudo chpasswd
sudo usermod -aG sudo "$RDP_USERNAME"

mkdir -p ~/MisArchivos