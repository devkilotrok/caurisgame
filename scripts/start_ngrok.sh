#!/bin/bash

# Script pour démarrer ngrok et exposer le backend Laravel
# Le backend Laravel doit être en cours d'exécution sur le port 8000

echo "🚀 Démarrage de ngrok pour exposer le backend Laravel..."
echo "📍 Backend local: http://localhost:8000"
echo ""

# Vérifier si ngrok est déjà en cours d'exécution
if pgrep -x "ngrok" > /dev/null; then
    echo "⚠️  ngrok est déjà en cours d'exécution"
    echo "   Arrêtez-le d'abord avec: pkill ngrok"
    exit 1
fi

# Vérifier si le serveur Laravel répond
if ! curl -s http://localhost:8000 > /dev/null 2>&1; then
    echo "❌ Le serveur Laravel ne répond pas sur http://localhost:8000"
    echo "   Démarrez-le d'abord avec: cd /opt/lampp/htdocs/backendCauris && php artisan serve"
    exit 1
fi

# Démarrer ngrok en arrière-plan
echo "✅ Démarrage de ngrok..."
NGROK_LOG="$HOME/ngrok.log"
ngrok http 8000 > "$NGROK_LOG" 2>&1 &

# Attendre un peu pour que ngrok démarre
sleep 3

# Récupérer l'URL publique depuis l'API ngrok
NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | grep -o '"public_url":"https://[^"]*' | head -1 | cut -d'"' -f4)

if [ -z "$NGROK_URL" ]; then
    echo "⚠️  Impossible de récupérer l'URL ngrok automatiquement"
    echo "   Vérifiez manuellement: http://localhost:4040"
    echo "   Ou consultez les logs: tail -f $NGROK_LOG"
else
    echo ""
    echo "✅ ngrok démarré avec succès!"
    echo "🌐 URL publique: $NGROK_URL"
    echo ""
    echo "📝 Mettez à jour ApiConfig.baseUrl dans lib/config/api_config.dart avec:"
    echo "   ${NGROK_URL}/api"
    echo ""
    echo "🔍 Interface web ngrok: http://localhost:4040"
    echo "📋 Logs: tail -f /tmp/ngrok.log"
    echo ""
    echo "Pour arrêter ngrok: pkill ngrok"
fi

