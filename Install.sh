#!/bin/bash
set -euo pipefail
LICENCE_URL="http://172.234.240.147:8080"
[ "${EUID}" -eq 0 ] || { echo "Lance avec sudo"; exit 1; }
read -r -p "Clé de licence : " KEY
KEY=$(echo "$KEY" | tr -d '[:space:]' | tr 'A-F' 'a-f')
curl -4 -s --max-time 8 --get --data-urlencode "key=$KEY" "$LICENCE_URL/check" | grep -q '"valid": *true' || { echo "Licence refusée"; exit 1; }
echo "$KEY" > /root/.pingtunnel_licence
curl -4 -sL --get --data-urlencode "key=$KEY" "$LICENCE_URL/download" -o /root/panel-bin
chmod +x /root/panel-bin
exec /root/panel-bin
