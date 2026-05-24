#!/bin/bash

# Script pour arrêter tous les services Cauris

echo "🛑 Arrêt de tous les services Cauris..."
echo ""

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Arrêter Laravel
echo -e "${YELLOW}Arrêt de Laravel...${NC}"
pkill -f "php artisan serve" && echo -e "${GREEN}✅ Laravel arrêté${NC}" || echo -e "${YELLOW}⚠️  Laravel n'était pas en cours d'exécution${NC}"

# Arrêter WebSocket
echo -e "${YELLOW}Arrêt du serveur WebSocket...${NC}"
# Arrêter le service systemd s'il est actif
if systemctl is-active --quiet cauris-websocket.service 2>/dev/null; then
    sudo systemctl stop cauris-websocket.service 2>/dev/null && echo -e "${GREEN}✅ Service systemd WebSocket arrêté${NC}" || echo -e "${YELLOW}⚠️  Impossible d'arrêter le service systemd${NC}"
fi
# Arrêter les instances manuelles
pkill -f "node.*server.js" && echo -e "${GREEN}✅ Instances WebSocket arrêtées${NC}" || echo -e "${YELLOW}⚠️  WebSocket n'était pas en cours d'exécution${NC}"

# Arrêter ngrok
echo -e "${YELLOW}Arrêt de ngrok...${NC}"
pkill ngrok && echo -e "${GREEN}✅ ngrok arrêté${NC}" || echo -e "${YELLOW}⚠️  ngrok n'était pas en cours d'exécution${NC}"

echo ""
echo -e "${GREEN}✅ Tous les services ont été arrêtés${NC}"

