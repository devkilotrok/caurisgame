# Guide d'intégration des API - GameWebSocketService

## 📍 Où intégrer les API externes

### Étape 1 : Import des dépendances
```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
```

### Étape 2 : Configuration de l'URL du backend
```dart
// TODO: INTÉGRER L'API BACKEND
// Remplacer 'localhost:3000' par l'URL du serveur WebSocket réel
// Exemple de production : 'wss://api.cauris.com:3000'
// Exemple de développement : 'ws://192.168.1.100:3000'

Future<void> connect({String? serverUrl}) async {
  // Configuration de l'URL
  final url = serverUrl ?? 'ws://localhost:3000'; // ✅ À MODIFIER
```

### Étape 3 : Ajout de l'authentification
```dart
// TODO: AJOUTER L'AUTHENTIFICATION JWT
// Après la connexion WebSocket, envoyer le token d'authentification
// Exemple :
// await _emit('authenticate', {
//   'token': await UserService.instance.getAuthToken(),
// });
```

## 🔄 Méthodes à modifier pour l'API backend

### Méthode : `joinRoom()`
```dart
/// TODO: Remplacer par un appel API REST
/// Au lieu de WebSocket, vous pouvez utiliser HTTP POST
/// Exemple :
/// final response = await http.post(
///   Uri.parse('$apiUrl/rooms/$roomId/join'),
///   headers: {'Authorization': 'Bearer $token'},
///   body: jsonEncode({'playerName': playerName}),
/// );

Future<void> joinRoom(String roomId, String playerName) async {
  // Actuellement : WebSocket
  // À remplacer par : API REST si nécessaire
}
```

### Méthode : `playCard()`
```dart
/// TODO: Intégrer avec le backend pour validation
/// Le backend doit valider si la carte peut être jouée
/// selon les règles du jeu
/// Exemple :
/// final response = await http.post(
///   Uri.parse('$apiUrl/games/play-card'),
///   headers: {'Authorization': 'Bearer $token'},
///   body: jsonEncode({
///     'card': {'suit': cardSuit, 'value': cardValue},
///     'trickNumber': trickNumber,
///   }),
/// );
```

## 🗑️ Code à supprimer

### Code actuel (simulation locale) :
```dart
// ❌ À SUPPRIMER : Ces parties simulent le comportement local
// Toute la logique actuelle dans :
// - GameService.createRoom()
// - GameService.joinRoom()
// - LocalCardManager (gestion locale des cartes)
```

### À garder :
```dart
// ✅ À GARDER : Les structures de données
// - GameSession (modèle de session)
// - Les événements WebSocket
// - Les listeners
```

## 🔧 Exemple d'intégration complète

### 1. Créer un service API séparé
```dart
// lib/services/api/game_api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class GameApiService {
  static const String _baseUrl = 'https://api.cauris.com'; // ✅ À MODIFIER
  
  Future<Map<String, dynamic>> createRoom({
    required String roomName,
    required int minimumBet,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/rooms/create'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${await _getToken()}',
      },
      body: jsonEncode({
        'roomName': roomName,
        'minimumBet': minimumBet,
      }),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Erreur: ${response.statusCode}');
  }
}
```

### 2. Modifier GameService pour utiliser l'API
```dart
// lib/services/game/game_service.dart

final GameApiService _apiService = GameApiService.instance;

/// Créer une salle via API
Future<String?> createRoom(String roomName, int minimumBid) async {
  try {
    // ✅ Remplacer par appel API
    final result = await _apiService.createRoom(
      roomName: roomName,
      minimumBet: minimumBid,
    );

    return result['roomCode'];
  } catch (e) {
    print('Erreur API: $e');
    return null;
  }
}
```

## 📝 Checklist d'intégration

- [ ] Changer l'URL WebSocket en production
- [ ] Ajouter l'authentification JWT
- [ ] Créer un service API séparé
- [ ] Remplacer les méthodes par des appels API
- [ ] Gérer les erreurs réseau
- [ ] Ajouter les timeouts
- [ ] Implémenter le retry automatique
- [ ] Tester avec le backend réel

## 🚫 À supprimer après intégration

1. Les méthodes de simulation dans `RoomManager`
2. La gestion locale des cartes si le backend gère ça
3. Les hardcodage de données de test
4. Les `print()` de debug (remplacer par un logger)

## ✅ À garder absolument

1. La structure WebSocket pour le temps réel
2. Les modèles de données (Transaction, User, etc.)
3. La logique métier (règles du jeu)
4. La gestion d'état (Providers)

