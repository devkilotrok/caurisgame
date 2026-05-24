# 📡 Requirements Backend - Synchronisation Remplacement Joueurs par Bots

## Vue d'ensemble

Le frontend Flutter a été mis à jour pour gérer automatiquement le remplacement des joueurs déconnectés par des bots. Pour garantir une synchronisation complète entre tous les clients, le backend doit implémenter les endpoints suivants.

---

## 🔴 Endpoints API Requis

### 1. **POST `/api/rooms/replace-player`**

Remplace un joueur par un bot dans une room.

**Request Body:**
```json
{
  "room_id": "string",
  "player_name": "string",
  "bot_name": "string",
  "is_permanent": boolean
}
```

**Response:**
```json
{
  "success": true,
  "message": "Joueur remplacé par bot",
  "data": {
    "room_id": "string",
    "player_replaced": "string",
    "bot_name": "string",
    "is_permanent": boolean
  }
}
```

**Comportement:**
- Marquer le joueur comme remplacé dans la base de données
- Si `is_permanent = false`: Remplacement temporaire (déconnexion < 15s)
- Si `is_permanent = true`: Remplacement définitif (déconnexion > 15s ou départ manuel)
- Notifier tous les autres clients via WebSocket de ce changement
- Transférer toutes les statistiques du joueur au bot (scores, plis, annonces)

---

### 2. **POST `/api/rooms/restore-player`**

Restaure un joueur qui s'est reconnecté dans les 15 secondes.

**Request Body:**
```json
{
  "room_id": "string",
  "player_name": "string",
  "bot_name": "string"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Joueur restauré",
  "data": {
    "room_id": "string",
    "player_restored": "string",
    "bot_removed": "string"
  }
}
```

**Comportement:**
- Annuler le remplacement temporaire
- Retirer le bot remplaçant
- Restaurer le joueur dans la room
- Notifier tous les autres clients via WebSocket

---

### 3. **POST `/api/rooms/player-disconnected`**

Notifie le backend d'une déconnexion de joueur.

**Request Body:**
```json
{
  "room_id": "string",
  "player_name": "string"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Déconnexion notifiée"
}
```

**Comportement:**
- Enregistrer la déconnexion avec timestamp
- Lancer un timer de 15 secondes côté backend
- Si pas de reconnexion après 15s, rendre le remplacement permanent
- Notifier les autres clients

---

### 4. **POST `/api/rooms/player-reconnected`**

Notifie le backend d'une reconnexion de joueur.

**Request Body:**
```json
{
  "room_id": "string",
  "player_name": "string"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Reconnexion notifiée",
  "can_restore": boolean  // true si < 15s, false sinon
}
```

**Comportement:**
- Vérifier si la reconnexion est dans les 15 secondes
- Retourner `can_restore: true` si < 15s, `false` sinon
- Si `can_restore = true`, permettre la restauration automatique

---

### 5. **POST `/api/rooms/check-exclusion`**

Vérifie si un joueur est exclu définitivement d'une room.

**Request Body:**
```json
{
  "room_id": "string",
  "player_name": "string"
}
```

**Response:**
```json
{
  "success": true,
  "is_excluded": boolean,
  "reason": "string"  // "disconnected_too_long" | "manual_leave" | "not_excluded"
}
```

**Comportement:**
- Vérifier si le joueur a été exclu définitivement
- Retourner `is_excluded: true` si exclu, `false` sinon
- Inclure la raison de l'exclusion

---

## 🔔 Événements WebSocket Requis

Le backend doit émettre ces événements WebSocket pour synchroniser tous les clients :

1. **`player_replaced`**
   ```json
   {
     "event": "player_replaced",
     "data": {
       "room_id": "string",
       "player_name": "string",
       "bot_name": "string",
       "is_permanent": boolean
     }
   }
   ```

2. **`player_restored`**
   ```json
   {
     "event": "player_restored",
     "data": {
       "room_id": "string",
       "player_name": "string",
       "bot_name": "string"
     }
   }
   ```

3. **`player_disconnected`**
   ```json
   {
     "event": "player_disconnected",
     "data": {
       "room_id": "string",
       "player_name": "string",
       "timestamp": "ISO8601"
     }
   }
   ```

4. **`player_reconnected`**
   ```json
   {
     "event": "player_reconnected",
     "data": {
       "room_id": "string",
       "player_name": "string",
       "can_restore": boolean
     }
   }
   ```

---

## 📊 Transfert de Statistiques

Lors du remplacement d'un joueur par un bot, le backend doit :

1. **Conserver les scores globaux** : Le bot hérite des scores du joueur au même index
2. **Transférer les plis gagnés** : Les plis du joueur dans le round actuel → bot
3. **Transférer les annonces** : Les annonces du joueur → bot
4. **Transférer les cartes** : Les cartes en main du joueur → bot
5. **Conserver l'historique des rounds** : Les statistiques des rounds passés restent au même index

---

## ⚠️ Cas Spéciaux

### Bot Remplaçant Gagnant

Si un bot remplaçant gagne la partie, **100% de la cagnotte** va à l'entreprise (pas 90%/10%).

Le backend doit :
- Détecter si le gagnant est un bot remplaçant (`isReplacementBot = true`)
- Appliquer la règle 100% entreprise au lieu de 90%/10%
- Enregistrer cette information dans `finalizeGame`

---

## 🔄 Workflow Complet

### Déconnexion Temporaire (< 15s)
1. Client détecte déconnexion → `POST /api/rooms/player-disconnected`
2. Backend enregistre timestamp
3. Client remplace temporairement par bot → `POST /api/rooms/replace-player` (is_permanent: false)
4. Backend émet `player_replaced` via WebSocket
5. Si reconnexion < 15s :
   - Client → `POST /api/rooms/player-reconnected`
   - Backend vérifie timestamp, retourne `can_restore: true`
   - Client → `POST /api/rooms/restore-player`
   - Backend émet `player_restored` via WebSocket
6. Si pas de reconnexion après 15s :
   - Backend rend permanent automatiquement
   - Backend émet `player_replaced` avec `is_permanent: true`

### Déconnexion Définitive (> 15s ou départ manuel)
1. Client détecte déconnexion ou départ manuel
2. Client → `POST /api/rooms/replace-player` (is_permanent: true)
3. Backend marque joueur comme exclu définitivement
4. Backend émet `player_replaced` via WebSocket
5. Si joueur tente de revenir :
   - Client → `POST /api/rooms/check-exclusion`
   - Backend retourne `is_excluded: true`
   - Client affiche dialog d'erreur et redirige vers création de salon

---

## 📝 Notes Importantes

1. **Synchronisation bidirectionnelle** : Le frontend envoie les notifications, mais le backend doit aussi émettre des événements WebSocket pour synchroniser tous les clients.

2. **Timing critique** : Les 15 secondes de grâce doivent être gérés de manière cohérente entre frontend et backend.

3. **Persistance** : Tous les remplacements doivent être persistés en base de données pour permettre la vérification lors des reconnexions.

4. **Statistiques** : Le transfert de statistiques doit être atomique pour éviter les incohérences.

---

## ✅ Tests Recommandés

1. Test déconnexion < 15s → reconnexion → restauration
2. Test déconnexion > 15s → exclusion définitive
3. Test départ manuel → exclusion immédiate
4. Test bot remplaçant gagnant → 100% entreprise
5. Test tentative retour après exclusion → dialog erreur
6. Test synchronisation multi-clients via WebSocket

---

## 📞 Contact

Pour toute question sur l'implémentation frontend, voir `lib/interfaces/game/game_room_page.dart` (fonctions `_replacePlayerWithBot`, `_handlePlayerDisconnection`, `_handlePlayerReconnection`, `_restorePlayer`).

---

## 📚 Ressources Supplémentaires

1. **Exemples de Code Backend** : Voir `BACKEND_IMPLEMENTATION_EXAMPLES.md` pour des exemples complets en PHP, Node.js et Python.

2. **Migration SQL** : Voir `database/migration_player_replacements.sql` pour les scripts SQL nécessaires.

3. **Intégration Frontend Complète** : Le frontend est maintenant entièrement intégré avec :
   - Appels API pour notifier le backend
   - Listeners WebSocket pour recevoir les événements backend
   - Synchronisation bidirectionnelle complète

