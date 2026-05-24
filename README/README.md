# 🎮 Cauris Degué Callbreak

Application mobile de jeu de cartes multijoueur en temps réel développée avec **Flutter** (frontend) et **Laravel** (backend).

## 📱 À propos

Cauris Degué Callbreak est un jeu de cartes multijoueur permettant de jouer seul contre des bots intelligents ou en ligne avec d'autres joueurs. L'application intègre un système de paiement, une gestion des salons en temps réel et des fonctionnalités sociales.

## ✨ Fonctionnalités principales

- 🔐 **Authentification complète** : Inscription, connexion, gestion de profil
- 🤖 **Mode solo** : Jouez contre des bots IA intelligents
- 👥 **Mode multijoueur** : Créez ou rejoignez des salons pour jouer à 4
- 💰 **Système de paiement** : Gestion des mises (Cauris) avec débits/crédits automatiques
- ⚡ **Temps réel** : Synchronisation instantanée via WebSocket
- 🎴 **Animations fluides** : Animations de cartes et transitions soignées
- 🔄 **Gestion des déconnexions** : Remplacement automatique par bots (fenêtre de 15s pour reconnexion)
- 📊 **Système de scores** : Suivi des points globaux et tableaux de scores par manche
- 📈 **Statistiques** : Historique des parties et performances des joueurs

## 🏗️ Architecture

```
.
├── cauris_app/              # Frontend Flutter
│   ├── lib/
│   │   ├── interfaces/      # Pages UI (auth, jeu, paramètres)
│   │   ├── models/          # Modèles de données (GameSession, LocalCardManager)
│   │   ├── services/        # Services API et WebSocket
│   │   └── ...
│   └── pubspec.yaml
│
└── backendCauris/            # Backend Laravel
    ├── app/
    │   ├── Http/Controllers/API/  # Contrôleurs API REST
    │   ├── Models/          # Modèles Eloquent
    │   └── Services/        # Services métier (WebSocketService)
    ├── routes/api.php       # Routes API
    ├── database/migrations/ # Migrations MySQL
    └── websocket-server/    # Serveur WebSocket Node.js + Socket.io
```

## 🛠️ Stack technique

### Frontend
- **Flutter** 3.9+
- **Dart** 3.9+
- **Animations personnalisées**
- **State Management** (StatefulWidget)

### Backend
- **Laravel** 10+
- **PHP** 8+
- **MySQL** (base de données)
- **Laravel Sanctum** (authentification)

### Temps réel
- **Node.js**
- **Socket.io**
- **WebSocket**

## 📦 Prérequis

- Flutter SDK 3.9+
- PHP 8.0+
- Composer
- Node.js 18+
- MySQL 8.0+
- XAMPP/LAMP (pour le backend local)

## 🚀 Installation

### Frontend (Flutter)

```bash
cd cauris_app
flutter pub get
flutter run
```

### Backend (Laravel)

```bash
cd backendCauris
composer install
cp .env.example .env
php artisan key:generate
php artisan migrate
php artisan serve
```

### WebSocket Server

```bash
cd backendCauris/websocket-server
npm install
node server.js
```

## 🔧 Configuration

1. **Base de données** : Configurer MySQL et importer le schéma depuis `database/cauris_schema.sql`
2. **Variables d'environnement** : Configurer `.env` dans `backendCauris/`
3. **WebSocket** : Configurer `WEBSOCKET_SERVER_URL` dans `.env`

## 📱 Plateformes supportées

- ✅ Android
- ✅ iOS
- ⚠️ Web (partiel)

## 🎯 Fonctionnalités détaillées

### Jeu
- Distribution automatique des cartes (13 par joueur)
- Phase d'annonces avec timer
- Phase de jeu avec règles du Callbreak
- Calcul automatique des scores
- Fin de partie avec répartition des gains

### Réseau
- Création de salons avec code unique
- Rejoindre un salon via code
- Synchronisation en temps réel des actions
- Gestion des déconnexions et reconnexions

### Paiement
- Vérification de solde avant création/rejoindre salon
- Débit automatique à l'entrée dans un salon
- Crédit en cas d'annulation
- Distribution des gains en fin de partie

## 📸 Captures d'écran

_À ajouter : captures d'écran de l'application_

## 🤝 Contribution

Les contributions sont les bienvenues ! N'hésitez pas à ouvrir une issue ou une pull request.

## 📝 License

[À définir]

## 👥 Auteurs

[Votre nom/équipe]

---

**Note** : Ce projet est en développement actif. Certaines fonctionnalités peuvent être en cours d'implémentation.

