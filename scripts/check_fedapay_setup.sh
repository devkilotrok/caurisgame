#!/bin/bash

# Script de vérification du système FedaPay
# Vérifie que tous les services nécessaires sont actifs
# Mode local (sans ngrok)

echo "🔍 Vérification du système FedaPay (Mode Local)..."
echo ""

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. Vérifier que Laravel est démarré
echo "1️⃣ Vérification de Laravel..."
if curl -s http://localhost:8000/api/payment/balance > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Laravel est accessible sur http://localhost:8000${NC}"
    
    # Récupérer l'IP locale
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    if [ -n "$LOCAL_IP" ]; then
        echo "   → IP locale détectée: $LOCAL_IP"
        echo "   → URL complète: http://$LOCAL_IP:8000/api"
        
        # Tester l'accessibilité via IP locale
        if curl -s "http://$LOCAL_IP:8000/api/payment/balance" > /dev/null 2>&1; then
            echo -e "${GREEN}   ✅ Backend accessible via IP locale${NC}"
        else
            echo -e "${YELLOW}   ⚠️  Backend non accessible via IP locale (peut être normal si non authentifié)${NC}"
            echo "   → Assurez-vous que Laravel écoute sur 0.0.0.0: php artisan serve --host=0.0.0.0"
        fi
    fi
else
    echo -e "${RED}❌ Laravel n'est pas accessible sur http://localhost:8000${NC}"
    echo "   → Démarrer avec: cd /opt/lampp/htdocs/backendCauris && php artisan serve --host=0.0.0.0"
fi
echo ""

# 3. Vérifier la configuration FedaPay dans .env
echo "3️⃣ Vérification de la configuration FedaPay..."
ENV_FILE="/opt/lampp/htdocs/backendCauris/.env"
if [ -f "$ENV_FILE" ]; then
    if grep -q "FEDAPAY_API_KEY" "$ENV_FILE"; then
        FEDAPAY_KEY=$(grep "FEDAPAY_API_KEY" "$ENV_FILE" | cut -d'=' -f2 | tr -d ' ')
        if [ -n "$FEDAPAY_KEY" ] && [ "$FEDAPAY_KEY" != "" ]; then
            echo -e "${GREEN}✅ FEDAPAY_API_KEY est configuré${NC}"
        else
            echo -e "${RED}❌ FEDAPAY_API_KEY est vide${NC}"
        fi
    else
        echo -e "${RED}❌ FEDAPAY_API_KEY non trouvé dans .env${NC}"
    fi
    
    if grep -q "FEDAPAY_SECRET_KEY" "$ENV_FILE"; then
        FEDAPAY_SECRET=$(grep "FEDAPAY_SECRET_KEY" "$ENV_FILE" | cut -d'=' -f2 | tr -d ' ')
        if [ -n "$FEDAPAY_SECRET" ] && [ "$FEDAPAY_SECRET" != "" ]; then
            echo -e "${GREEN}✅ FEDAPAY_SECRET_KEY est configuré${NC}"
        else
            echo -e "${RED}❌ FEDAPAY_SECRET_KEY est vide${NC}"
        fi
    else
        echo -e "${RED}❌ FEDAPAY_SECRET_KEY non trouvé dans .env${NC}"
    fi
    
    if grep -q "APP_URL" "$ENV_FILE"; then
        APP_URL=$(grep "APP_URL" "$ENV_FILE" | cut -d'=' -f2 | tr -d ' ')
        if [[ "$APP_URL" == https://* ]]; then
            echo -e "${GREEN}✅ APP_URL est en HTTPS: $APP_URL${NC}"
        elif [[ "$APP_URL" == http://* ]]; then
            echo -e "${YELLOW}⚠️  APP_URL est en HTTP: $APP_URL${NC}"
            echo "   → En développement local, HTTP est acceptable"
            echo "   → En production, FedaPay nécessite HTTPS pour les callbacks"
        else
            echo -e "${YELLOW}⚠️  APP_URL format invalide: $APP_URL${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  APP_URL non trouvé dans .env${NC}"
        echo "   → Ajoutez: APP_URL=http://192.168.1.80:8000"
    fi
else
    echo -e "${RED}❌ Fichier .env non trouvé: $ENV_FILE${NC}"
fi
echo ""

# 4. Vérifier les logs récents
echo "4️⃣ Vérification des logs récents..."
if [ -f "/opt/lampp/htdocs/backendCauris/storage/logs/laravel.log" ]; then
    LARAVEL_ERRORS=$(tail -n 100 /opt/lampp/htdocs/backendCauris/storage/logs/laravel.log | grep -i "error\|exception" | wc -l)
    if [ "$LARAVEL_ERRORS" -gt 0 ]; then
        echo -e "${YELLOW}⚠️  $LARAVEL_ERRORS erreur(s) trouvée(s) dans les logs Laravel récents${NC}"
        echo "   → Consulter: tail -f /opt/lampp/htdocs/backendCauris/storage/logs/laravel.log"
    else
        echo -e "${GREEN}✅ Aucune erreur récente dans les logs Laravel${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Fichier de log Laravel non trouvé${NC}"
fi
echo ""

# 5. Résumé et recommandations
echo "📋 Résumé:"
echo ""

LOCAL_IP=$(hostname -I | awk '{print $1}')

if curl -s http://localhost:8000/api/payment/balance > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Laravel est actif${NC}"
    echo ""
    echo "💡 Pour tester un dépôt:"
    echo "   1. Vérifiez que l'IP locale est correcte dans ApiConfig.baseUrl"
    if [ -n "$LOCAL_IP" ]; then
        echo "   2. IP locale détectée: $LOCAL_IP"
        echo "   3. Lancez l'app avec:"
        echo "      flutter run --dart-define=BASE_URL=http://$LOCAL_IP:8000/api"
        echo ""
        echo "   ⚠️  IMPORTANT: Assurez-vous que:"
        echo "   • Votre téléphone est sur le même réseau WiFi que votre PC"
        echo "   • Laravel écoute sur 0.0.0.0: php artisan serve --host=0.0.0.0"
    else
        echo "   2. Lancez l'app normalement: flutter run"
        echo "   3. Vérifiez que l'IP dans ApiConfig.baseUrl est correcte"
    fi
else
    echo -e "${RED}❌ Laravel n'est pas actif${NC}"
    echo ""
    echo "💡 Actions recommandées:"
    echo "   1. Démarrer Laravel:"
    echo "      cd /opt/lampp/htdocs/backendCauris"
    echo "      php artisan serve --host=0.0.0.0 --port=8000"
    echo "   2. Vérifier la configuration dans .env"
    echo "   3. Vérifier que le port 8000 n'est pas occupé: lsof -i :8000"
fi

echo ""

