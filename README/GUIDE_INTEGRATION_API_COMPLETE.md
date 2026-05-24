# 📘 Guide complet d'intégration des API externes

## 🎯 Vue d'ensemble

Ce document détaille **où** et **comment** intégrer les API backend et externes dans l'application Flutter Cauris.

## 📍 Emplacements d'intégration

### 1. Services WebSocket
**Fichier** : `lib/services/websocket/game_websocket_service.dart`

**À modifier** :
```dart
// Ligne 28 : URL du serveur WebSocket
final url = serverUrl ?? 'ws://localhost:3000'; // ✅ À MODIFIER

// Exemple production :
final url = serverUrl ?? 'wss://api.cauris.com:3000';

// Exemple développement local :
final url = serverUrl ?? 'ws://192.168.1.100:3000';
```

**À ajouter** :
```dart
// Après la connexion (ligne 34) : Authentification JWT
Future<void> connect({String? serverUrl}) async {
  // ... connexion existante ...
  
  // ✅ AJOUTER ICI :
  // Attendre que la connexion soit établie
  await Future.delayed(Duration(milliseconds: 100));
  
  // Envoyer le token d'authentification
  await _emit('authenticate', {
    'token': UserService.instance.authToken,
  });
}
```

**À supprimer** : Rien (le code actuel est bon)

---

### 2. Service de jeu
**Fichier** : `lib/services/game/game_service.dart`

**À modifier** :
```dart
// Lignes 42-46 : Appel à _roomManager.createRoom()
// ❌ SIMULATION LOCALE - À SUPPRIMER

final result = await _roomManager.createRoom(
  roomName: roomName,
  minimumBet: minimumBid,
  creatorPseudo: _userService.currentUserPseudo ?? 'Anonymous',
);

// ✅ REMPLACER PAR :
import 'package:http/http.dart' as http;
import 'dart:convert';

final response = await http.post(
  Uri.parse('${await _getApiUrl()}/api/rooms/create'),
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${UserService.instance.authToken}',
  },
  body: jsonEncode({
    'roomName': roomName,
    'minimumBet': minimumBid,
    'creatorId': UserService.instance.currentUserPseudo,
  }),
);

if (response.statusCode == 200) {
  final data = jsonDecode(response.body);
  return data['roomCode'];
}
return null;
```

**À ajouter** : Créer un service API séparé
**Fichier** : `lib/services/api/game_api_service.dart`

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class GameApiService {
  static const String _baseUrl = 'https://api.cauris.com'; // ✅ À MODIFIER
  
  Future<Map<String, dynamic>> createRoom({
    required String roomName,
    required int minimumBet,
  }) async {
    // Implémentation de l'appel API
  }
  
  Future<bool> joinRoom(String roomCode) async {
    // Implémentation de l'appel API
  }
  
  Future<void> startGame() async {
    // Implémentation de l'appel API
  }
}
```

**À supprimer** :
- L'utilisation de `RoomManager` pour les opérations CRUD
- Les méthodes de simulation dans `RoomManager.createRoom()`
- Les fichiers : `lib/models/room/room_manager.dart` (si non utilisé ailleurs)

---

### 3. Service utilisateur
**Fichier** : `lib/services/user/user_service.dart`

**À modifier** :
```dart
// Ligne 44 : Méthode login()
void login(String pseudo, String email) {
  _currentUserPseudo = pseudo;
  _currentUserEmail = email;
  _isLoggedIn = true;
}

// ✅ REMPLACER PAR :
Future<bool> login(String email, String password) async {
  try {
    final response = await http.post(
      Uri.parse('${await _getApiUrl()}/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _authToken = data['token'];
      _currentUserPseudo = data['user']['pseudo'];
      _currentUserEmail = data['user']['email'];
      _isLoggedIn = true;
      return true;
    }
    return false;
  } catch (e) {
    print('Erreur de connexion: $e');
    return false;
  }
}
```

**À ajouter** :
- Variable `_authToken` pour stocker le JWT
- Getter `authToken`
- Méthode pour obtenir l'URL de l'API
- Gestion du rafraîchissement du token

**À supprimer** :
- Méthode `simulateLogin()` (ligne 63)

---

### 4. Service de transactions (Caisse)
**Fichier** : `lib/interfaces/caisse/caisse_page.dart`

**À modifier** :
```dart
// Ligne 729 : Méthode _handleRetrait()
void _handleRetrait() {
  // ... validation locale ...
  
  // ❌ SIMULATION LOCALE - À SUPPRIMER
  final newTransaction = Transaction(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    type: 'retrait',
    // ...
  );
  
  // ✅ REMPLACER PAR :
  // Appel API pour créer la transaction
  _createRetraitTransaction(
    cauris: caurisInt,
    fcfa: montantFcfa,
    beneficiaire: beneficiaireName,
    phone: numeroTelephone,
  );
}

// Nouvelle méthode à créer
Future<void> _createRetraitTransaction({
  required int cauris,
  required int fcfa,
  required String beneficiaire,
  required String phone,
}) async {
  try {
    final response = await http.post(
      Uri.parse('${await _getApiUrl()}/api/transactions/retrait'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${UserService.instance.authToken}',
      },
      body: jsonEncode({
        'type': 'retrait',
        'caurisAmount': cauris,
        'fcfaAmount': fcfa,
        'beneficiaireName': beneficiaire,
        'phoneNumber': phone,
      }),
    );
    
    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      // Afficher le message de succès
      _showSuccessDialog('Retrait initié', 'Votre demande a été enregistrée');
    } else {
      _showErrorDialog('Erreur lors de la création de la transaction');
    }
  } catch (e) {
    _showErrorDialog('Erreur de connexion: $e');
  }
}
```

**À ajouter** :
- Import de `http` et `dart:convert`
- Méthode `_getApiUrl()` pour obtenir l'URL de base
- Appels API pour toutes les opérations de transaction

**À supprimer** :
- La logique de simulation locale
- Les transactions stockées localement (garder seulement pour l'affichage)

---

## 🔧 Configuration de l'URL de l'API

**Créer** : `lib/config/api_config.dart`

```dart
class ApiConfig {
  // Développement local
  static const String devUrl = 'http://localhost:8000';
  
  // Production
  static const String prodUrl = 'https://api.cauris.com';
  
  // URL actuelle (à changer selon l'environnement)
  static String get baseUrl {
    // En développement
    return devUrl;
    
    // En production, remplacer par :
    // return prodUrl;
  }
  
  // URL du WebSocket
  static String get websocketUrl {
    // Développement local
    return 'ws://192.168.1.100:3000';
    
    // Production
    // return 'wss://api.cauris.com:3000';
  }
}
```

---

## 🗑️ Fichiers et code à supprimer

### Après intégration complète

1. **À supprimer** : `lib/models/room/room_manager.dart`
   - Remplacé par les appels API directs

2. **À modifier** : `lib/models/game/local_card_manager.dart`
   - Garder uniquement pour la gestion locale des cartes UI
   - Supprimer la logique de distribution qui devrait venir du backend

3. **À supprimer** : Méthodes de simulation
   - `RoomManager.createRoom()` (simulation)
   - `RoomManager.joinRoom()` (simulation)
   - `UserService.simulateLogin()`

4. **À garder** :
   - ✅ Structure des modèles (Transaction, User, etc.)
   - ✅ Provider pour l'état
   - ✅ Logique métier du jeu
   - ✅ WebSocket pour le temps réel

---

## 📋 Checklist d'intégration

### Étape 1 : Configuration
- [ ] Créer `lib/config/api_config.dart`
- [ ] Configurer les URL de base
- [ ] Ajouter la dépendance `http` dans `pubspec.yaml`

### Étape 2 : Service API
- [ ] Créer `lib/services/api/game_api_service.dart`
- [ ] Créer `lib/services/api/auth_api_service.dart`
- [ ] Créer `lib/services/api/transaction_api_service.dart`
- [ ] Implémenter les méthodes CRUD

### Étape 3 : Authentification
- [ ] Ajouter le stockage du token JWT
- [ ] Ajouter le refresh automatique du token
- [ ] Implémenter la gestion des sessions

### Étape 4 : WebSocket
- [ ] Changer l'URL du serveur
- [ ] Ajouter l'authentification après la connexion
- [ ] Tester la connexion

### Étape 5 : Remplacement du code
- [ ] Remplacer `RoomManager` par les appels API
- [ ] Remplacer `UserService.login()` par l'API
- [ ] Remplacer les transactions par l'API

### Étape 6 : Nettoyage
- [ ] Supprimer le code de simulation
- [ ] Supprimer les méthodes de test
- [ ] Ajouter la gestion des erreurs réseau
- [ ] Ajouter les logs de débogage

---

## 🚀 Exemple complet d'intégration

### Avant (Simulation)
```dart
Future<String?> createRoom(String roomName, int minimumBid) async {
  final result = await _roomManager.createRoom(
    roomName: roomName,
    minimumBet: minimumBid,
    creatorPseudo: _userService.currentUserPseudo ?? 'Anonymous',
  );
  
  if (result != null && result['success'] == true) {
    return result['roomCode'] as String?;
  }
  return null;
}
```

### Après (Avec API)
```dart
Future<String?> createRoom(String roomName, int minimumBid) async {
  try {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/rooms/create'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${UserService.instance.authToken}',
      },
      body: jsonEncode({
        'roomName': roomName,
        'minimumBet': minimumBid,
      }),
    );
    
    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return data['roomCode'];
    }
    
    if (response.statusCode == 401) {
      // Token expiré, rafraîchir
      await UserService.instance.refreshToken();
      // Réessayer la requête
      return createRoom(roomName, minimumBid);
    }
    
    throw Exception('Erreur: ${response.statusCode}');
  } catch (e) {
    print('Erreur création salle: $e');
    return null;
  }
}
```

---

## 📚 Ressources supplémentaires

- Voir `lib/services/websocket/INTEGRATION_API.md` pour les détails WebSocket
- Voir `README_SERVICES_PROVIDERS.md` pour l'architecture
- Voir `database/MODIFICATIONS_TRANSACTIONS.md` pour la base de données

