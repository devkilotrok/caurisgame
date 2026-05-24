# 🎯 Backend CAURIS - Guide de Démarrage

## 📁 Emplacement du Backend

Le backend Laravel a été créé dans : `/home/adolphe/backendCauris/`

## 🚀 Installation et Configuration

### 1. Installer les dépendances

```bash
cd /home/adolphe/backendCauris
composer install
```

### 2. Configuration de l'environnement

Copier le fichier `.env.example` vers `.env` :

```bash
cp .env.example .env
```

Éditer le fichier `.env` avec vos paramètres de base de données :

```env
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=cauris_db
DB_USERNAME=root
DB_PASSWORD=

APP_URL=http://localhost
```

### 3. Générer la clé d'application

```bash
php artisan key:generate
```

### 4. Créer la base de données

```bash
mysql -u root -p < database/cauris_schema.sql
```

### 5. Lancer les migrations

```bash
php artisan migrate
```

### 6. Démarrer le serveur

```bash
php artisan serve
```

Le backend sera accessible sur : `http://localhost:8000`

## 📚 Documentation des API

### Base URL
```
http://localhost:8000/api
```

### Authentification

Toutes les routes API (sauf l'inscription et la connexion) nécessitent un token d'authentification.

**Headers requis :**
```
Authorization: Bearer {token}
Accept: application/json
Content-Type: application/json
```

---

## 📡 Endpoints API

### 🔐 Authentification

#### POST /api/register
Crée un nouveau compte utilisateur.

**Body:**
```json
{
  "pseudo": "Lewis",
  "email": "lewis@example.com",
  "password": "password123",
  "password_confirmation": "password123"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Compte créé avec succès",
  "data": {
    "user": {
      "user_id": 1,
      "pseudo": "Lewis",
      "email": "lewis@example.com"
    },
    "token": "1|abc123..."
  }
}
```

#### POST /api/login
Connecte un utilisateur.

**Body:**
```json
{
  "email": "lewis@example.com",
  "password": "password123"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Connexion réussie",
  "data": {
    "user": {
      "user_id": 1,
      "pseudo": "Lewis",
      "email": "lewis@example.com"
    },
    "token": "1|abc123..."
  }
}
```

---

### 👥 Amis

#### GET /api/friends
Récupère la liste des amis de l'utilisateur connecté.

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "friendship_id": 1,
      "friend": {
        "user_id": 2,
        "pseudo": "Bil",
        "email": "bil@example.com",
        "avatar": "🤖"
      },
      "status": "accepted",
      "created_at": "2025-01-01 12:00:00"
    }
  ]
}
```

#### POST /api/friends/request
Envoie une demande d'amitié.

**Body:**
```json
{
  "friend_id": 2
}
```

#### POST /api/friends/accept/{request_id}
Accepte une demande d'amitié.

#### POST /api/friends/reject/{request_id}
Refuse une demande d'amitié.

---

### 🎮 Salles de Jeu

#### POST /api/rooms/create
Crée une nouvelle salle.

**Body:**
```json
{
  "room_name": "Room 1",
  "minimum_bet": 50
}
```

**Response:**
```json
{
  "success": true,
  "message": "Salon créé avec succès",
  "data": {
    "room_id": 1,
    "room_name": "Room 1",
    "room_code": "ABC123",
    "minimum_bet": 50,
    "creator_id": 1
  }
}
```

#### POST /api/rooms/join
Rejoint une salle existante.

**Body:**
```json
{
  "room_code": "ABC123"
}
```

#### GET /api/rooms/{room_id}
Récupère les informations d'une salle.

#### GET /api/rooms
Récupère la liste des salles disponibles.

---

### 🎯 Jeu

#### POST /api/games/start
Démarre une nouvelle partie.

**Body:**
```json
{
  "room_id": 1
}
```

#### POST /api/games/{game_id}/announce
Fait une annonce pour un round.

**Body:**
```json
{
  "round_number": 1,
  "announcement_value": 3
}
```

#### POST /api/games/{game_id}/play-card
Joue une carte.

**Body:**
```json
{
  "trick_id": 1,
  "card_code": "AS"
}
```

#### GET /api/games/{game_id}/scores
Récupère les scores actuels d'une partie.

---

## 🔧 Prochaines Étapes

### Dans le Panel Admin (Web)

1. Créer les routes d'administration
2. Créer les vues de gestion
3. Intégrer les statistiques

### Dans l'App Mobile (Flutter)

1. Créer un service API
2. Intégrer les appels API
3. Gérer l'authentification avec tokens

## 📝 Documentation Complète

La documentation complète sera disponible dans le dossier `backendCauris/API_DOCUMENTATION.md` une fois le backend terminé.

---

**Note:** Le backend est créé dans `/home/adolphe/backendCauris/`. Vous pouvez le déplacer vers `htdocs/backendCauris` selon vos préférences.

