#!/bin/bash

# Script pour démarrer tous les tunnels ngrok (Laravel + WebSocket)
# Utilise le fichier de configuration ngrok.yml

echo "🚀 Démarrage de tous les tunnels ngrok..."
echo ""

# Vérifier si ngrok est déjà en cours d'exécution
if pgrep -x "ngrok" > /dev/null; then
    echo "⚠️  ngrok est déjà en cours d'exécution"
    echo "   Arrêtez-le d'abord avec: pkill ngrok"
    exit 1
fi

# Vérifier que les serveurs répondent
if ! curl -s http://localhost:8000 > /dev/null 2>&1; then
    echo "❌ Le serveur Laravel ne répond pas sur http://localhost:8000"
    echo "   Démarrez-le d'abord avec: cd /opt/lampp/htdocs/backendCauris && php artisan serve"
    exit 1
fi

if ! curl -s http://localhost:3000/health > /dev/null 2>&1; then
    echo "❌ Le serveur WebSocket ne répond pas sur http://localhost:3000"
    echo "   Démarrez-le d'abord avec: ./start_websocket.sh"
    exit 1
fi

# Vérifier si le fichier de configuration existe
if [ ! -f ~/.ngrok2/ngrok.yml ]; then
    echo "❌ Fichier de configuration ngrok.yml introuvable"
    echo "   Créez-le dans ~/.ngrok2/ngrok.yml"
    exit 1
fi

echo "✅ Démarrage de ngrok avec configuration..."
echo ""

# Démarrer ngrok avec tous les tunnels définis dans ngrok.yml
NGROK_LOG_ALL="$HOME/ngrok_all.log"
ngrok start --all > "$NGROK_LOG_ALL" 2>&1 &

# Attendre un peu pour que ngrok démarre
sleep 4

# Récupérer les URLs depuis l'API ngrok
echo "📡 Récupération des URLs des tunnels..."
TUNNELS_JSON=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null)

if [ -z "$TUNNELS_JSON" ]; then
    echo "⚠️  Impossible de récupérer les URLs automatiquement"
    echo "   Vérifiez manuellement: http://localhost:4040"
    echo "   Ou consultez les logs: tail -f $NGROK_LOG_ALL"
    exit 1
fi

# Extraire les URLs
LARAVEL_URL=$(echo "$TUNNELS_JSON" | grep -o '"public_url":"https://[^"]*' | grep -A 1 "8000" | head -1 | cut -d'"' -f4 || echo "$TUNNELS_JSON" | python3 -c "import sys, json; data=json.load(sys.stdin); print([t['public_url'] for t in data.get('tunnels', []) if '8000' in str(t.get('config', {}).get('addr', ''))][0] if data.get('tunnels') else '')" 2>/dev/null)

WEBSOCKET_URL=$(echo "$TUNNELS_JSON" | grep -o '"public_url":"https://[^"]*' | grep -A 1 "3000" | head -1 | cut -d'"' -f4 || echo "$TUNNELS_JSON" | python3 -c "import sys, json; data=json.load(sys.stdin); print([t['public_url'] for t in data.get('tunnels', []) if '3000' in str(t.get('config', {}).get('addr', ''))][0] if data.get('tunnels') else '')" 2>/dev/null)

# Si les URLs ne sont pas trouvées avec grep, utiliser Python
if [ -z "$LARAVEL_URL" ] || [ -z "$WEBSOCKET_URL" ]; then
    LARAVEL_URL=$(echo "$TUNNELS_JSON" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for tunnel in data.get('tunnels', []):
        addr = str(tunnel.get('config', {}).get('addr', ''))
        if '8000' in addr:
            print(tunnel.get('public_url', ''))
            break
except:
    pass
" 2>/dev/null)
    
    WEBSOCKET_URL=$(echo "$TUNNELS_JSON" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for tunnel in data.get('tunnels', []):
        addr = str(tunnel.get('config', {}).get('addr', ''))
        if '3000' in addr:
            print(tunnel.get('public_url', ''))
            break
except:
    pass
" 2>/dev/null)
fi

if [ -z "$LARAVEL_URL" ] || [ -z "$WEBSOCKET_URL" ]; then
    echo "⚠️  Impossible de récupérer toutes les URLs automatiquement"
    echo ""
    echo "📋 Tunnels détectés:"
    echo "$TUNNELS_JSON" | python3 -m json.tool 2>/dev/null | grep -A 5 "public_url" || echo "$TUNNELS_JSON"
    echo ""
    echo "   Vérifiez manuellement: http://localhost:4040"
    echo "   Ou consultez les logs: tail -f $NGROK_LOG_ALL"
else
    echo ""
    echo "✅ Tous les tunnels ngrok démarrés avec succès!"
    echo ""
    echo "🌐 URL Laravel (API): $LARAVEL_URL"
    echo "🌐 URL WebSocket: $WEBSOCKET_URL"
    echo ""
    echo "📝 Mettez à jour la configuration:"
    echo ""
    echo "   Dans lib/config/api_config.dart:"
    echo "   - baseUrl: ${LARAVEL_URL}/api"
    echo "   - websocketUrl: ${WEBSOCKET_URL}"
    echo ""
    echo "🔍 Interface web ngrok: http://localhost:4040"
    echo "📋 Logs: tail -f $NGROK_LOG_ALL"
    echo ""
    echo "Pour arrêter tous les tunnels: pkill ngrok"
fi
