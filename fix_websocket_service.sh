#!/bin/bash

# Script pour corriger et redémarrer le service WebSocket

echo "🔧 Correction du service WebSocket..."
echo ""

# Arrêter toutes les instances existantes
echo "🛑 Arrêt des instances existantes..."
pkill -f "node.*server.js" 2>/dev/null
sleep 2

# Vérifier que le port est libéré
if netstat -tlnp 2>/dev/null | grep -q ':3000' || ss -tlnp 2>/dev/null | grep -q ':3000'; then
    echo "⚠️  Le port 3000 est encore utilisé"
    echo "   PID utilisant le port:"
    netstat -tlnp 2>/dev/null | grep :3000 || ss -tlnp 2>/dev/null | grep :3000
    exit 1
fi

echo "✅ Port 3000 libéré"
echo ""

# Redémarrer le service systemd
if [ "$EUID" -eq 0 ]; then
    echo "🔄 Redémarrage du service systemd..."
    systemctl restart cauris-websocket.service
    sleep 2
    
    if systemctl is-active --quiet cauris-websocket.service; then
        echo "✅ Service redémarré avec succès!"
        echo ""
        echo "📊 Statut:"
        systemctl status cauris-websocket.service --no-pager -l | head -10
    else
        echo "❌ Le service n'a pas démarré"
        echo "   Logs: sudo journalctl -u cauris-websocket -n 20"
    fi
else
    echo "⚠️  Ce script nécessite les permissions root pour redémarrer le service"
    echo "   Exécutez: sudo ./fix_websocket_service.sh"
    echo ""
    echo "   Ou manuellement:"
    echo "   sudo systemctl restart cauris-websocket"
fi


