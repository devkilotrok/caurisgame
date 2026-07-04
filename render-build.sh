#!/usr/bin/env bash
# Quitter en cas d'erreur
set -o errexit

echo "⬇️ Téléchargement de Flutter..."
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"

echo "🧹 Nettoyage..."
flutter clean
flutter pub get

echo "🏗️ Compilation de l'application Web..."
flutter build web --dart-define=BASE_URL=$BASE_URL --dart-define=WEBSOCKET_URL=$WEBSOCKET_URL

echo "✅ Compilation terminée !"
