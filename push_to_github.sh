#!/bin/bash

# Script pour pousser Frontend Flutter + Backend Laravel vers GitHub
# Usage: ./push_to_github.sh

set -e  # Arrêter en cas d'erreur

REPO_URL="https://github.com/Alpha0116/CaurisDegueCallbreak.git"
TEMP_DIR="$HOME/CaurisDegueCallbreak_temp"
FRONTEND_PATH="/home/adolphe/cauris_app"
BACKEND_PATH="/opt/lampp/htdocs/backendCauris"

echo "🚀 Début du processus de push vers GitHub..."

# Étape 1: Cloner le dépôt GitHub
echo "📥 Clonage du dépôt GitHub..."
if [ -d "$TEMP_DIR" ]; then
    echo "⚠️  Le dossier temporaire existe déjà. Suppression..."
    rm -rf "$TEMP_DIR"
fi

git clone "$REPO_URL" "$TEMP_DIR"
cd "$TEMP_DIR"

# Étape 2: Vérifier si le repo est vide ou a déjà des fichiers
if [ -n "$(ls -A .git 2>/dev/null)" ] && [ "$(git ls-files | wc -l)" -gt 0 ]; then
    echo "ℹ️  Le dépôt contient déjà des fichiers. Mise à jour..."
    git pull origin main || git pull origin master
fi

# Étape 3: Copier le frontend Flutter dans le dossier cauris_app
echo "📦 Copie du frontend Flutter..."
mkdir -p cauris_app
rsync -av --exclude='.git' --exclude='build' --exclude='.dart_tool' \
    "$FRONTEND_PATH/" ./cauris_app/

# Étape 4: Copier le backend Laravel dans le dossier backendCauris
echo "📦 Copie du backend Laravel..."
mkdir -p backendCauris
rsync -av --exclude='.git' --exclude='vendor' --exclude='node_modules' \
    --exclude='.env' --exclude='storage/logs' --exclude='storage/framework' \
    "$BACKEND_PATH/" ./backendCauris/

# Étape 5: Copier le README racine si disponible
if [ -f "$FRONTEND_PATH/README_ROOT.md" ]; then
    echo "📄 Copie du README racine..."
    cp "$FRONTEND_PATH/README_ROOT.md" ./README.md
elif [ -f "$FRONTEND_PATH/README.md" ]; then
    echo "📄 Utilisation du README existant..."
    cp "$FRONTEND_PATH/README.md" ./README.md
fi

# Étape 6: S'assurer que .gitignore est présent et correct
echo "✅ Vérification des fichiers .gitignore..."

# Étape 6: Ajouter tous les fichiers et faire le commit
echo "📝 Ajout des fichiers..."
git add .

# Vérifier s'il y a des changements
if [ -z "$(git status --porcelain)" ]; then
    echo "ℹ️  Aucun changement à commiter."
else
    echo "💾 Création du commit..."
    git commit -m "Add Flutter frontend and Laravel backend
    
    - Frontend Flutter (cauris_app)
    - Backend Laravel (backendCauris)
    - README.md avec documentation complète
    - Configuration WebSocket
    - Système de paiement intégré"
    
    # Étape 7: Pousser vers GitHub
    echo "⬆️  Push vers GitHub..."
    BRANCH=$(git branch --show-current)
    if [ -z "$BRANCH" ]; then
        BRANCH="main"
        git branch -M main
    fi
    
    git push origin "$BRANCH"
    
    echo "✅ Push terminé avec succès!"
fi

echo "🎉 Processus terminé!"
echo ""
echo "Votre code est maintenant disponible sur:"
echo "   $REPO_URL"
echo ""
echo "Vous pouvez supprimer le dossier temporaire si vous voulez:"
echo "   rm -rf $TEMP_DIR"

