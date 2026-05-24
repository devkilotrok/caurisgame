#!/bin/bash

# Script de démarrage complet pour le backend Cauris
# Démarre : Laravel, WebSocket Socket.io, et ngrok

echo "🚀 Démarrage complet du backend Cauris..."
echo ""

# Couleurs pour les messages
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Fonction pour vérifier si un processus est en cours d'exécution
is_running() {
    pgrep -f "$1" > /dev/null
}

# Fonction pour attendre qu'un service soit prêt
wait_for_service() {
    local url=$1
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s "$url" > /dev/null 2>&1; then
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 1
    done
    return 1
}

# 1. Démarrer Laravel (port 8000)
echo -e "${YELLOW}1️⃣  Vérification du serveur Laravel...${NC}"
if is_running "php artisan serve"; then
    echo -e "${GREEN}   ✅ Laravel est déjà en cours d'exécution${NC}"
else
    echo -e "${YELLOW}   📦 Démarrage de Laravel...${NC}"
    cd /opt/lampp/htdocs/backendCauris || {
        echo -e "${RED}   ❌ Répertoire backendCauris introuvable${NC}"
        exit 1
    }
    
    # Démarrer Laravel en arrière-plan sur 0.0.0.0 pour être accessible depuis le réseau
    nohup php artisan serve --host=0.0.0.0 --port=8000 > "$HOME/laravel.log" 2>&1 &
    LARAVEL_PID=$!
    
    # Attendre que Laravel soit prêt
    if wait_for_service "http://localhost:8000"; then
        echo -e "${GREEN}   ✅ Laravel démarré (PID: $LARAVEL_PID)${NC}"
    else
        echo -e "${RED}   ❌ Laravel n'a pas démarré correctement${NC}"
        echo -e "${YELLOW}   📋 Logs: tail -f $HOME/laravel.log${NC}"
    fi
fi
echo ""

# 2. Démarrer WebSocket Socket.io (port 3000)
echo -e "${YELLOW}2️⃣  Vérification du serveur WebSocket Socket.io...${NC}"

# Vérifier si le service systemd est actif
if systemctl is-active --quiet cauris-websocket.service 2>/dev/null; then
    echo -e "${GREEN}   ✅ WebSocket Socket.io est déjà en cours d'exécution (via systemd)${NC}"
elif is_running "node.*server.js"; then
    echo -e "${GREEN}   ✅ WebSocket Socket.io est déjà en cours d'exécution${NC}"
else
    echo -e "${YELLOW}   📦 Démarrage du serveur WebSocket...${NC}"
    cd /opt/lampp/htdocs/backendCauris/websocket-server || {
        echo -e "${RED}   ❌ Répertoire websocket-server introuvable${NC}"
        exit 1
    }
    
    # Vérifier si node_modules existe
    if [ ! -d "node_modules" ]; then
        echo -e "${YELLOW}   📦 Installation des dépendances npm...${NC}"
        npm install || {
            echo -e "${RED}   ❌ Erreur lors de l'installation des dépendances${NC}"
            exit 1
        }
    fi
    
    # Utiliser le chemin complet de node
    NODE_PATH=$(which node)
    if [ -z "$NODE_PATH" ]; then
        NODE_PATH="/home/adolphe/.nvm/versions/node/v22.20.0/bin/node"
    fi
    
    # Démarrer le serveur WebSocket en arrière-plan
    nohup "$NODE_PATH" server.js > "$HOME/websocket.log" 2>&1 &
    WEBSOCKET_PID=$!
    
    # Attendre que le serveur WebSocket soit prêt
    if wait_for_service "http://localhost:3000/health"; then
        echo -e "${GREEN}   ✅ WebSocket Socket.io démarré (PID: $WEBSOCKET_PID)${NC}"
    else
        echo -e "${RED}   ❌ WebSocket Socket.io n'a pas démarré correctement${NC}"
        echo -e "${YELLOW}   📋 Logs: tail -f $HOME/websocket.log${NC}"
    fi
fi
echo ""

# 3. Démarrer ngrok
echo -e "${YELLOW}3️⃣  Vérification de ngrok...${NC}"
if is_running "ngrok"; then
    echo -e "${GREEN}   ✅ ngrok est déjà en cours d'exécution${NC}"
else
    echo -e "${YELLOW}   📦 Démarrage de ngrok...${NC}"
    
    # Vérifier que les serveurs sont prêts
    if ! wait_for_service "http://localhost:8000" 2>/dev/null; then
        echo -e "${RED}   ❌ Laravel n'est pas prêt, impossible de démarrer ngrok${NC}"
        exit 1
    fi
    
    # Démarrer ngrok avec tous les tunnels
    NGROK_LOG="$HOME/ngrok_all.log"
    if [ -f ~/.ngrok2/ngrok.yml ]; then
        nohup ngrok start --all > "$NGROK_LOG" 2>&1 &
    else
        # Si pas de config, démarrer juste pour Laravel
        nohup ngrok http 8000 > "$NGROK_LOG" 2>&1 &
    fi
    
    NGROK_PID=$!
    
    # Attendre un peu pour que ngrok démarre
    sleep 4
    
    # Vérifier que ngrok est actif
    if is_running "ngrok"; then
        echo -e "${GREEN}   ✅ ngrok démarré (PID: $NGROK_PID)${NC}"
        
        # Récupérer l'URL ngrok
        sleep 2
        NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | grep -o '"public_url":"https://[^"]*' | head -1 | cut -d'"' -f4)
        if [ -n "$NGROK_URL" ]; then
            echo -e "${GREEN}   🌐 URL publique: $NGROK_URL${NC}"
        fi
    else
        echo -e "${RED}   ❌ ngrok n'a pas démarré correctement${NC}"
        echo -e "${YELLOW}   📋 Logs: tail -f $NGROK_LOG${NC}"
    fi
fi
echo ""

# Résumé
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Démarrage terminé !${NC}"
echo ""
echo "📊 État des services:"
echo "  - Laravel:      http://localhost:8000"
echo "  - WebSocket:    http://localhost:3000"
echo "  - ngrok:        http://localhost:4040"
echo ""
echo "📋 Logs:"
echo "  - Laravel:      tail -f $HOME/laravel.log"
echo "  - WebSocket:    tail -f $HOME/websocket.log"
echo "  - ngrok:        tail -f $HOME/ngrok_all.log"
echo ""
echo "🛑 Pour arrêter tous les services:"
echo "  ./stop_all.sh"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"

