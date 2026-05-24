#!/bin/bash

# Script pour démarrer le serveur WebSocket Node.js

echo "🚀 Démarrage du serveur WebSocket Node.js..."
echo "📍 Répertoire: /opt/lampp/htdocs/backendCauris/websocket-server"
echo ""

cd /opt/lampp/htdocs/backendCauris/websocket-server || {
    echo "❌ Répertoire websocket-server introuvable"
    exit 1
}

# Vérifier si node_modules existe
if [ ! -d "node_modules" ]; then
    echo "📦 Installation des dépendances npm..."
    npm install || {
        echo "❌ Erreur lors de l'installation des dépendances"
        exit 1
    }
    echo "✅ Dépendances installées"
    echo ""
fi

# Vérifier si le serveur est déjà en cours d'exécution
if pgrep -f "node.*server.js" > /dev/null; then
    echo "⚠️  Le serveur WebSocket est déjà en cours d'exécution"
    echo "   PID: $(pgrep -f 'node.*server.js')"
    echo "   Pour l'arrêter: pkill -f 'node.*server.js'"
    exit 1
fi

# Vérifier si le port 3000 est déjà utilisé
if netstat -tlnp 2>/dev/null | grep -q ':3000' || ss -tlnp 2>/dev/null | grep -q ':3000'; then
    echo "⚠️  Le port 3000 est déjà utilisé"
    echo "   Arrêtez le processus qui utilise ce port ou changez le port dans server.js"
    exit 1
fi

echo "✅ Démarrage du serveur WebSocket sur le port 3000..."
echo ""

# Démarrer le serveur en arrière-plan
nohup node server.js > "$HOME/websocket.log" 2>&1 &
WS_PID=$!

# Attendre un peu pour que le serveur démarre
sleep 2

# Vérifier si le serveur est bien démarré
if ps -p $WS_PID > /dev/null; then
    echo "✅ Serveur WebSocket démarré avec succès!"
    echo "   PID: $WS_PID"
    echo "   Port: 3000"
    echo "   Logs: tail -f $HOME/websocket.log"
    echo ""
    echo "📡 Pour exposer via ngrok, utilisez:"
    echo "   ngrok http 3000"
    echo ""
    echo "Pour arrêter le serveur: kill $WS_PID"
else
    echo "❌ Erreur lors du démarrage du serveur"
    echo "   Consultez les logs: cat $HOME/websocket.log"
    exit 1
fi

