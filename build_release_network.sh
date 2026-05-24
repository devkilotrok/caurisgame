#!/bin/bash

# Script pour construire une version release de l'application Flutter
# configurée pour être accessible depuis d'autres appareils sur le même réseau

set -e

# Couleurs pour les messages
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}📱 Build Release pour Réseau Local${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# 1. Détecter l'IP locale
echo -e "${YELLOW}1️⃣  Détection de l'IP locale...${NC}"
LOCAL_IP=$(hostname -I | awk '{print $1}')

if [ -z "$LOCAL_IP" ]; then
    echo -e "${RED}❌ Impossible de détecter l'IP locale${NC}"
    echo "   Veuillez spécifier votre IP manuellement:"
    read -p "   Entrez votre IP locale (ex: 192.168.1.87): " LOCAL_IP
fi

if [ -z "$LOCAL_IP" ]; then
    echo -e "${RED}❌ IP non fournie, arrêt du script${NC}"
    exit 1
fi

echo -e "${GREEN}   ✅ IP locale détectée: ${LOCAL_IP}${NC}"
echo ""

# 2. Vérifier que les services backend sont démarrés
echo -e "${YELLOW}2️⃣  Vérification des services backend...${NC}"

# Vérifier Laravel
if curl -s "http://${LOCAL_IP}:8000/api/payment/balance" > /dev/null 2>&1; then
    echo -e "${GREEN}   ✅ Laravel est accessible sur ${LOCAL_IP}:8000${NC}"
else
    echo -e "${RED}   ⚠️  Laravel n'est pas accessible sur ${LOCAL_IP}:8000${NC}"
    echo -e "${YELLOW}   💡 Assurez-vous que Laravel écoute sur 0.0.0.0:${NC}"
    echo "      php artisan serve --host=0.0.0.0 --port=8000"
    echo ""
    read -p "   Continuer quand même ? (y/n): " CONTINUE
    if [ "$CONTINUE" != "y" ] && [ "$CONTINUE" != "Y" ]; then
        exit 1
    fi
fi

# Vérifier WebSocket
if curl -s "http://${LOCAL_IP}:3000" > /dev/null 2>&1 || nc -z "${LOCAL_IP}" 3000 2>/dev/null; then
    echo -e "${GREEN}   ✅ WebSocket est accessible sur ${LOCAL_IP}:3000${NC}"
else
    echo -e "${YELLOW}   ⚠️  WebSocket n'est pas accessible sur ${LOCAL_IP}:3000${NC}"
    echo -e "${YELLOW}   💡 Assurez-vous que le serveur WebSocket écoute sur 0.0.0.0${NC}"
    echo ""
fi
echo ""

# 3. Nettoyer les builds précédents (optionnel)
echo -e "${YELLOW}3️⃣  Nettoyage des builds précédents...${NC}"
read -p "   Nettoyer les builds précédents ? (y/n): " CLEAN
if [ "$CLEAN" = "y" ] || [ "$CLEAN" = "Y" ]; then
    flutter clean
    echo -e "${GREEN}   ✅ Nettoyage terminé${NC}"
fi
echo ""

# 4. Récupérer les dépendances
echo -e "${YELLOW}4️⃣  Récupération des dépendances...${NC}"
flutter pub get
echo -e "${GREEN}   ✅ Dépendances récupérées${NC}"
echo ""

# 5. Construire l'APK release
echo -e "${YELLOW}5️⃣  Construction de l'APK release...${NC}"
echo -e "${BLUE}   Configuration:${NC}"
echo "      - BASE_URL: http://${LOCAL_IP}:8000/api"
echo "      - WEBSOCKET_URL: ws://${LOCAL_IP}:3000"
echo ""

BASE_URL="http://${LOCAL_IP}:8000/api"
WEBSOCKET_URL="ws://${LOCAL_IP}:3000"

flutter build apk --release \
    --dart-define=BASE_URL="${BASE_URL}" \
    --dart-define=WEBSOCKET_URL="${WEBSOCKET_URL}"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}   ✅ Build terminé avec succès!${NC}"
else
    echo -e "${RED}   ❌ Erreur lors du build${NC}"
    exit 1
fi
echo ""

# 6. Afficher le chemin de l'APK
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
if [ -f "$APK_PATH" ]; then
    APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✅ Build terminé avec succès!${NC}"
    echo ""
    echo -e "${BLUE}📦 Fichier APK:${NC}"
    echo "   Chemin: $(pwd)/${APK_PATH}"
    echo "   Taille: ${APK_SIZE}"
    echo ""
    echo -e "${BLUE}📱 Pour installer sur votre téléphone:${NC}"
    echo "   1. Transférez l'APK sur votre téléphone (USB, email, etc.)"
    echo "   2. Activez 'Sources inconnues' dans les paramètres Android"
    echo "   3. Installez l'APK"
    echo ""
    echo -e "${BLUE}🌐 Configuration réseau:${NC}"
    echo "   - Assurez-vous que votre téléphone est sur le même réseau WiFi"
    echo "   - IP du serveur: ${LOCAL_IP}"
    echo "   - API: http://${LOCAL_IP}:8000/api"
    echo "   - WebSocket: ws://${LOCAL_IP}:3000"
    echo ""
    echo -e "${BLUE}✅ Vérifications avant test:${NC}"
    echo "   1. Laravel doit être démarré: php artisan serve --host=0.0.0.0 --port=8000"
    echo "   2. WebSocket doit être démarré et écouter sur 0.0.0.0:3000"
    echo "   3. Firewall doit autoriser les ports 8000 et 3000"
    echo ""
    echo -e "${YELLOW}💡 Pour tester la connexion depuis votre téléphone:${NC}"
    echo "   Ouvrez un navigateur sur votre téléphone et allez à:"
    echo "   http://${LOCAL_IP}:8000/api/payment/balance"
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
else
    echo -e "${RED}❌ APK non trouvé à l'emplacement attendu${NC}"
    exit 1
fi
