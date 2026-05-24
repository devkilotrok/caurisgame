#!/bin/bash

# Script pour vérifier que les services sont correctement configurés
# pour être accessibles depuis d'autres appareils sur le réseau local

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}🔍 Vérification de la Configuration Réseau${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# 1. Détecter l'IP locale
LOCAL_IP=$(hostname -I | awk '{print $1}')
echo -e "${YELLOW}1️⃣  IP locale: ${LOCAL_IP}${NC}"
echo ""

# 2. Vérifier Laravel
echo -e "${YELLOW}2️⃣  Vérification de Laravel...${NC}"

# Vérifier si Laravel écoute sur 0.0.0.0
LARAVEL_LISTEN=$(lsof -i :8000 2>/dev/null | grep LISTEN | awk '{print $9}' || echo "")
if echo "$LARAVEL_LISTEN" | grep -q "0.0.0.0:8000\|*:8000"; then
    echo -e "${GREEN}   ✅ Laravel écoute sur 0.0.0.0:8000 (accessible depuis le réseau)${NC}"
elif echo "$LARAVEL_LISTEN" | grep -q "127.0.0.1:8000\|localhost:8000"; then
    echo -e "${RED}   ❌ Laravel écoute seulement sur localhost:8000${NC}"
    echo -e "${YELLOW}   💡 Redémarrez avec: php artisan serve --host=0.0.0.0 --port=8000${NC}"
else
    echo -e "${YELLOW}   ⚠️  Laravel ne semble pas être démarré${NC}"
fi

# Tester l'accès depuis l'IP locale
if curl -s "http://${LOCAL_IP}:8000/api/payment/balance" > /dev/null 2>&1; then
    echo -e "${GREEN}   ✅ Laravel accessible depuis ${LOCAL_IP}:8000${NC}"
else
    echo -e "${RED}   ❌ Laravel non accessible depuis ${LOCAL_IP}:8000${NC}"
fi
echo ""

# 3. Vérifier WebSocket
echo -e "${YELLOW}3️⃣  Vérification du WebSocket...${NC}"

# Vérifier si le port 3000 est ouvert
if nc -z "${LOCAL_IP}" 3000 2>/dev/null || timeout 2 bash -c "echo > /dev/tcp/${LOCAL_IP}/3000" 2>/dev/null; then
    echo -e "${GREEN}   ✅ WebSocket accessible sur ${LOCAL_IP}:3000${NC}"
else
    echo -e "${RED}   ❌ WebSocket non accessible sur ${LOCAL_IP}:3000${NC}"
    echo -e "${YELLOW}   💡 Vérifiez que le serveur WebSocket écoute sur 0.0.0.0${NC}"
fi
echo ""

# 4. Vérifier le firewall
echo -e "${YELLOW}4️⃣  Vérification du firewall...${NC}"
if command -v ufw > /dev/null 2>&1; then
    UFW_STATUS=$(sudo ufw status 2>/dev/null | head -1 || echo "inactive")
    if echo "$UFW_STATUS" | grep -q "active"; then
        echo -e "${YELLOW}   ⚠️  UFW est actif${NC}"
        echo -e "${YELLOW}   💡 Assurez-vous que les ports 8000 et 3000 sont ouverts:${NC}"
        echo "      sudo ufw allow 8000/tcp"
        echo "      sudo ufw allow 3000/tcp"
    else
        echo -e "${GREEN}   ✅ UFW n'est pas actif (pas de blocage)${NC}"
    fi
else
    echo -e "${YELLOW}   ⚠️  UFW non installé, vérifiez manuellement votre firewall${NC}"
fi
echo ""

# 5. Résumé et recommandations
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}📋 Résumé${NC}"
echo ""

echo -e "${BLUE}🌐 Configuration pour tester depuis d'autres appareils:${NC}"
echo "   - IP du serveur: ${LOCAL_IP}"
echo "   - API: http://${LOCAL_IP}:8000/api"
echo "   - WebSocket: ws://${LOCAL_IP}:3000"
echo ""

echo -e "${BLUE}✅ Pour tester depuis votre téléphone:${NC}"
echo "   1. Assurez-vous que votre téléphone est sur le même réseau WiFi"
echo "   2. Ouvrez un navigateur sur votre téléphone"
echo "   3. Allez à: http://${LOCAL_IP}:8000/api/payment/balance"
echo "   4. Si vous voyez une réponse JSON, la connexion fonctionne!"
echo ""

echo -e "${BLUE}📱 Pour construire l'APK avec cette configuration:${NC}"
echo "   ./build_release_network.sh"
echo ""

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
