# Description du Repository Cauris

## Description courte (pour GitHub/GitLab)

Application mobile de jeu de cartes multijoueur en temps réel (Cauris Degué Callbreak) avec frontend Flutter et backend Laravel. Fonctionnalités : authentification, création/rejoindre des salons, jeu avec bots ou joueurs humains, système de paiement intégré, WebSocket pour communication temps réel, gestion des scores et statistiques.

---

## Description complète (pour README)

### 🎮 Cauris Degué Callbreak

Application mobile de jeu de cartes multijoueur en temps réel développée avec Flutter (frontend) et Laravel (backend). 

### ✨ Fonctionnalités principales

- **Authentification complète** : Inscription, connexion, gestion de profil
- **Modes de jeu** :
  - Mode solo avec bots (IA)
  - Mode multijoueur en ligne (4 joueurs)
- **Gestion des salons** : Création, rejoindre via code, liste des salons disponibles
- **Système de paiement intégré** : Gestion des mises (Cauris), débits/crédits automatiques
- **Communication temps réel** : WebSocket pour synchronisation en direct des parties
- **Animations fluides** : Animations de cartes, transitions entre états du jeu
- **Gestion des déconnexions** : Remplacement automatique par bots avec fenêtre de reconnexion (15s)
- **Système de scores** : Suivi des points globaux, tableau des scores par manche
- **Statistiques** : Historique des parties, scores des joueurs

### 🏗️ Architecture

**Frontend (Flutter)**
- Interface utilisateur responsive
- Gestion d'état locale (StatefulWidget, LocalCardManager)
- Services API pour communication backend
- WebSocket client pour temps réel
- Animations personnalisées

**Backend (Laravel)**
- API REST pour toutes les opérations
- Authentification Sanctum
- Base de données MySQL
- Service WebSocket (Node.js + Socket.io)
- Gestion des transactions (paiements, scores)

### 📦 Structure du projet

```
.
├── cauris_app/              # Frontend Flutter
│   ├── lib/
│   │   ├── interfaces/      # Pages UI
│   │   ├── models/          # Modèles de données
│   │   ├── services/        # Services API/WebSocket
│   │   └── ...
│   └── pubspec.yaml
│
└── backendCauris/            # Backend Laravel
    ├── app/
    │   ├── Http/
    │   │   └── Controllers/  # Contrôleurs API
    │   ├── Models/          # Modèles Eloquent
    │   └── Services/        # Services métier
    ├── routes/
    │   └── api.php          # Routes API
    ├── database/
    │   └── migrations/      # Migrations DB
    └── websocket-server/    # Serveur WebSocket Node.js
```

### 🛠️ Technologies

- **Frontend** : Flutter 3.9+, Dart
- **Backend** : Laravel 10+, PHP 8+
- **Base de données** : MySQL
- **WebSocket** : Node.js, Socket.io
- **Authentification** : Laravel Sanctum

### 📱 Plateformes supportées

- Android
- iOS
- Web (partiel)

### 🔐 Sécurité

- Authentification token-based (Sanctum)
- Validation des données côté serveur
- Protection CSRF
- Gestion sécurisée des transactions financières

### 🎯 Cas d'usage

- Jeu entre amis en ligne
- Entraînement contre des bots
- Tournois avec système de mises
- Suivi des performances et statistiques

---

## Installation

Voir les fichiers README dans chaque dossier :
- `cauris_app/README.md` pour le frontend
- `backendCauris/README.md` pour le backend

---

## License

[À définir]

---

## Auteur

[Votre nom/équipe]

