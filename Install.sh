#!/bin/bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; RESET='\033[0m'
[ "${EUID}" -eq 0 ] || { echo -e "${RED}Lance avec sudo${RESET}"; exit 1; }

LICENCE_URL="http://172.234.240.147:8080"
KEY_FILE="/root/.pingtunnel_licence"
DEST="/root/panel-bin"

command -v curl >/dev/null 2>&1 || {
    apt-get update -qq && apt-get install -y -qq curl ca-certificates
}

if [ -s "$KEY_FILE" ]; then
    KEY=$(tr -d '[:space:]' < "$KEY_FILE")
else
    read -r -p "Clé de licence : " KEY
fi
KEY=$(printf '%s' "$KEY" | tr -d '[:space:]' | tr 'A-F' 'a-f')
[[ "$KEY" =~ ^[0-9a-f]{4}(-[0-9a-f]{4}){3}$ ]] || { echo -e "${RED}Clé invalide${RESET}"; exit 1; }

echo -e "${CYAN}Vérification de la licence...${RESET}"
CODE=$(curl -4 -s -o /tmp/bs-check.json -w '%{http_code}' --max-time 8 \
       --get --data-urlencode "key=$KEY" "$LICENCE_URL/check" || echo "000")
if [ "$CODE" != "200" ] || ! grep -Eq '"valid": ?true' /tmp/bs-check.json; then
    echo -e "${RED}Licence refusée (HTTP $CODE)${RESET}"
    cat /tmp/bs-check.json 2>/dev/null; echo
    exit 1
fi
umask 077
printf '%s\n' "$KEY" > "$KEY_FILE"
date +%s > /root/.pingtunnel_licence_ok
echo -e "${GREEN}✓ Licence OK${RESET}"

echo -e "${CYAN}Téléchargement du panneau...${RESET}"
TMP=$(mktemp /tmp/panel.XXXXXX)
trap 'rm -f "$TMP"' EXIT

HTTP=$(curl -4 -sL -o "$TMP" -w '%{http_code}' --max-time 60 \
       --get --data-urlencode "key=$KEY" "$LICENCE_URL/download" || echo "000")
[ "$HTTP" = "200" ] || { echo -e "${RED}Échec (HTTP $HTTP)${RESET}"; exit 1; }
[ -s "$TMP" ] || { echo -e "${RED}Fichier vide${RESET}"; exit 1; }

file "$TMP" | grep -q ELF || { echo -e "${RED}Fichier corrompu${RESET}"; exit 1; }

install -m 0700 "$TMP" "$DEST"
rm -f "$TMP"
trap - EXIT
echo -e "${GREEN}✓ Installé${RESET}"

exec "$DEST"
