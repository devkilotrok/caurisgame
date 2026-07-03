#!/bin/bash

# Script d'installation pour le démarrage automatique complet
# (XAMPP + Laravel + Socket.io + ngrok)

echo "🔧 Installation du démarrage automatique (XAMPP + Laravel + Socket.io + ngrok)..."
echo ""

# Vérifier les permissions root
if [ "$EUID" -ne 0 ]; then 
    echo "⚠️  Ce script nécessite les permissions root (sudo)"
    echo "   Exécutez: sudo ./install_autostart.sh"
    exit 1
fi

# Déterminer le répertoire du script (cauris_app)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Liste des services à installer
SERVICES=(
    "cauris-xampp.service"
    "cauris-laravel.service"
    "cauris-websocket.service"
    "cauris-ngrok.service"
)

# Vérifier que tous les fichiers de services existent
for SERVICE in "${SERVICES[@]}"; do
    if [ ! -f "$SCRIPT_DIR/$SERVICE" ]; then
        echo "❌ Fichier $SERVICE introuvable dans $SCRIPT_DIR"
        echo "   Assurez-vous d'exécuter ce script depuis le répertoire cauris_app"
        exit 1
    fi
done

# Copier les services
for SERVICE in "${SERVICES[@]}"; do
    SOURCE_FILE="$SCRIPT_DIR/$SERVICE"
    DEST_FILE="/etc/systemd/system/$SERVICE"
    echo "📋 Copie de $SERVICE → $DEST_FILE"
    cp "$SOURCE_FILE" "$DEST_FILE" || {
        echo "❌ Erreur lors de la copie de $SERVICE"
        exit 1
    }
done
echo "✅ Fichiers de services copiés."

# Recharger systemd
echo "🔄 Rechargement de systemd..."
systemctl daemon-reload

# Ordre d'activation/démarrage
START_ORDER=(
    "cauris-xampp.service"
    "cauris-laravel.service"
    "cauris-websocket.service"
    "cauris-ngrok.service"
)

for SERVICE in "${START_ORDER[@]}"; do
    echo ""
    echo "⚙️  Activation de $SERVICE..."
    systemctl enable "$SERVICE"

    case "$SERVICE" in
        cauris-websocket.service)
            echo "🛑 Arrêt des instances Node.js existantes..."
            pkill -f "node.*server.js" 2>/dev/null
            sleep 2
            ;;
        cauris-laravel.service)
            echo "🛑 Arrêt des processus php artisan serve existants..."
            pkill -f "php artisan serve" 2>/dev/null
            sleep 2
            ;;
        cauris-ngrok.service)
            echo "🛑 Arrêt des processus ngrok existants..."
            pkill -x "ngrok" 2>/dev/null
            sleep 2
            ;;
    esac

    echo "🚀 Démarrage de $SERVICE..."
    systemctl restart "$SERVICE"

    sleep 2
    if systemctl is-active --quiet "$SERVICE"; then
        echo "   ✅ $SERVICE démarré correctement"
    else
        echo "   ⚠️  $SERVICE n'a pas démarré correctement"
        echo "      Vérifiez: sudo journalctl -u $SERVICE -f"
        exit 1
    fi
done

echo ""
echo "✅ Tous les services ont été installés, activés et démarrés."
echo ""
echo "📊 Services installés :"
printf "  - %s\n" "${SERVICES[@]}"
echo ""
echo "📋 Commandes utiles :"
echo "  sudo systemctl status <service>"
echo "  sudo systemctl restart <service>"
echo "  sudo systemctl stop <service>"
echo "  sudo systemctl disable <service>"
echo ""
echo "ℹ️  Les services démarreront automatiquement au prochain démarrage du PC."

