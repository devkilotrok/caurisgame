# Services et Providers - Cauris App

## 📋 Vue d'ensemble

Ce document décrit l'architecture des Services et Providers de l'application Cauris Flutter.

## 🏗️ Architecture

### Structure des dossiers

```
lib/
├── services/          # Services (logique métier)
│   ├── user/
│   │   └── user_service.dart
│   ├── game/
│   │   └── game_service.dart
│   ├── storage/
│   │   └── storage_service.dart
│   └── websocket/
│       └── game_websocket_service.dart
│
└── providers/         # Providers (état global)
    ├── user_provider.dart
    ├── room_provider.dart
    └── websocket_provider.dart
```

### Différence Services vs Providers

**Services** : Logique métier pure, sans état UI
- Gèrent les opérations (API, WebSocket, stockage)
- Sont réutilisables et testables
- N'ont pas de dépendances à Flutter

**Providers** : État global + logique UI
- Gèrent l'état de l'application
- Connectent les Services aux Widgets
- Utilisent `ChangeNotifier` pour reconstruire l'UI

## 🔧 Services

### 1. UserService (`services/user/user_service.dart`)

Gère les informations de l'utilisateur connecté.

```dart
final userService = UserService.instance;

// Se connecter
userService.login('Lewis', 'lewis@example.com');

// Vérifier le statut
bool isLoggedIn = userService.isLoggedIn;
String? pseudo = userService.currentUserPseudo;
```

**Méthodes :**
- `login(String pseudo, String email)` : Connecter un utilisateur
- `logout()` : Déconnecter l'utilisateur
- `simulateLogin()` : Simuler une connexion pour les tests

**Propriétés :**
- `isLoggedIn` : Statut de connexion
- `currentUserPseudo` : Pseudo de l'utilisateur actuel
- `currentUserEmail` : Email de l'utilisateur actuel

### 2. GameService (`services/game/game_service.dart`)

Gère les opérations de jeu (création de salle, distribution des cartes, etc.).

```dart
final gameService = GameService.instance;

// Créer une salle
String? roomCode = await gameService.createRoom('Ma Salle', 2);

// Rejoindre une salle
bool success = await gameService.joinRoom('ABC123');

// Démarrer le jeu
await gameService.startGame();

// Obtenir la main du joueur
List<Map<String, dynamic>> hand = gameService.getPlayerHand();
```

**Méthodes :**
- `createRoom(String roomName, int minimumBid)` : Créer une salle
- `joinRoom(String roomCode)` : Rejoindre une salle
- `startGame()` : Démarrer le jeu
- `getPlayerHand()` : Obtenir la main du joueur actuel

**Accès aux singletons :**
- `gameSession` : Accès à `GameSession.instance`
- `cardManager` : Accès à `LocalCardManager.instance`

### 3. StorageService (`services/storage/storage_service.dart`)

Gère le stockage local avec SharedPreferences.

```dart
final storageService = StorageService.instance;

// Sauvegarder
await storageService.saveString('key', 'value');
await storageService.saveInt('count', 42);
await storageService.saveBool('flag', true);

// Récupérer
String? value = await storageService.getString('key');
int count = await storageService.getInt('count');
bool flag = await storageService.getBool('flag');
```

**Méthodes :**
- `saveString(String key, String value)` : Sauvegarder un String
- `getString(String key)` : Récupérer un String
- `saveBool(String key, bool value)` : Sauvegarder un booléen
- `getBool(String key)` : Récupérer un booléen
- `saveInt(String key, int value)` : Sauvegarder un int
- `getInt(String key)` : Récupérer un int
- `saveJson(String key, Map<String, dynamic> value)` : Sauvegarder un JSON
- `getJson(String key)` : Récupérer un JSON
- `remove(String key)` : Supprimer une clé
- `clear()` : Supprimer toutes les données

### 4. GameWebSocketService (`services/websocket/game_websocket_service.dart`)

Gère les communications WebSocket pour le jeu temps réel.

```dart
final wsService = GameWebSocketService.instance;

// Se connecter
await wsService.connect(serverUrl: 'ws://192.168.1.100:3000');

// Rejoindre une salle
await wsService.joinRoom('room123', 'Lewis');

// Écouter les événements
wsService.onCardPlayed().listen((data) {
  print('Carte jouée: $data');
});

// Jouer une carte
await wsService.playCard(
  cardSuit: 'spades',
  cardValue: 'A',
  trickNumber: 1,
);
```

**Méthodes principales :**
- `connect({String? serverUrl})` : Se connecter au serveur
- `joinRoom(String roomId, String playerName)` : Rejoindre une salle
- `leaveRoom()` : Quitter une salle
- `playCard({required String cardSuit, required String cardValue, required int trickNumber})` : Jouer une carte
- `makeAnnouncement(int announcement)` : Faire une annonce
- `startGame(List<String> players)` : Démarrer le jeu
- `disconnect()` : Se déconnecter

**Streams d'événements :**
- `onCardPlayed()` : Une carte a été jouée
- `onPlayerJoined()` : Un joueur a rejoint
- `onPlayerLeft()` : Un joueur a quitté
- `onAnnouncementMade()` : Une annonce a été faite
- `onGameStarted()` : Le jeu a démarré
- `onTrickWon()` : Un pli a été gagné
- `onRoundCompleted()` : Un round est terminé
- `onError()` : Une erreur est survenue
- `onDisconnect()` : Déconnexion du serveur
- `onAny()` : Tous les événements

## 🎯 Providers

### 1. UserProvider (`providers/user_provider.dart`)

Gère l'état de l'utilisateur et de l'authentification.

**Configuration :**
```dart
// Dans main.dart
ChangeNotifierProvider(create: (_) => UserProvider())
```

**Utilisation :**
```dart
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    
    return Text(userProvider.isLoggedIn 
      ? 'Connecté: ${userProvider.currentUserPseudo}'
      : 'Non connecté'
    );
  }
}
```

**Propriétés :**
- `isLoggedIn` : Statut de connexion
- `currentUserPseudo` : Pseudo de l'utilisateur
- `currentUserEmail` : Email de l'utilisateur

**Méthodes :**
- `login(String pseudo, String email)` : Se connecter
- `logout()` : Se déconnecter
- `_checkLoginStatus()` : Vérifier le statut au démarrage

**Fonctionnalités :**
- Sauvegarde automatique dans le stockage local
- Restauration automatique au démarrage
- Synchronisation avec `UserService`

### 2. RoomProvider (`providers/room_provider.dart`)

Gère l'état des salles et des parties.

**Configuration :**
```dart
// Dans main.dart
ChangeNotifierProvider(create: (_) => RoomProvider())
```

**Utilisation :**
```dart
class GameRoomPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final roomProvider = Provider.of<RoomProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Salle: ${roomProvider.currentRoomCode}'),
      ),
      body: roomProvider.isGameStarted
        ? GameBoard()
        : WaitingRoom(),
    );
  }
}
```

**Propriétés :**
- `currentRoomId` : ID de la salle actuelle
- `currentRoomCode` : Code de la salle
- `currentRoomName` : Nom de la salle
- `players` : Liste des joueurs
- `isInRoom` : Statut (dans une salle ou non)
- `isGameStarted` : Statut (jeu démarré ou non)
- `currentPlayerTurn` : Tour du joueur actuel

**Méthodes :**
- `createRoom(String roomName, int minimumBid)` : Créer une salle
- `joinRoom(String roomCode)` : Rejoindre une salle
- `startGame()` : Démarrer le jeu
- `leaveRoom()` : Quitter la salle
- `getGameSessionData()` : Obtenir les données de session

**Fonctionnalités :**
- Gestion automatique de l'état des salles
- Intégration avec WebSocket
- Synchronisation avec `GameService`

### 3. WebSocketProvider (`providers/websocket_provider.dart`)

Gère les communications WebSocket et l'état de la connexion.

**Configuration :**
```dart
// Dans main.dart
ChangeNotifierProvider(create: (_) => WebSocketProvider())
```

**Utilisation :**
```dart
class GameRoomPage extends StatefulWidget {
  @override
  _GameRoomPageState createState() => _GameRoomPageState();
}

class _GameRoomPageState extends State<GameRoomPage> {
  @override
  void initState() {
    super.initState();
    _initializeWebSocket();
  }

  Future<void> _initializeWebSocket() async {
    final wsProvider = Provider.of<WebSocketProvider>(context, listen: false);
    await wsProvider.connect(serverUrl: 'ws://192.168.1.100:3000');
  }

  @override
  Widget build(BuildContext context) {
    final wsProvider = Provider.of<WebSocketProvider>(context);
    
    return Scaffold(
      body: wsProvider.isConnected
        ? ConnectedWidget()
        : DisconnectedWidget(),
    );
  }
}
```

**Propriétés :**
- `isConnected` : Statut de connexion
- `currentRoomId` : ID de la salle actuelle
- `currentPlayerName` : Nom du joueur actuel
- `serverUrl` : URL du serveur WebSocket

**Méthodes :**
- `connect({String? serverUrl})` : Se connecter
- `joinRoom(String roomId, String playerName)` : Rejoindre une salle
- `leaveRoom()` : Quitter une salle
- `playCard({required String cardSuit, required String cardValue, required int trickNumber})` : Jouer une carte
- `makeAnnouncement(int announcement)` : Faire une annonce
- `startGame(List<String> players)` : Démarrer le jeu
- `disconnect()` : Se déconnecter

**Accès au service :**
- `wsService` : Accès à `GameWebSocketService` pour les listeners

**Fonctionnalités :**
- Connexion automatique aux événements
- Gestion automatique des erreurs
- Déconnexion automatique au dispose

## 🚀 Configuration dans main.dart

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/user_provider.dart';
import 'providers/room_provider.dart';
import 'providers/websocket_provider.dart';
import 'interfaces/home/home_page.dart';
import 'interfaces/parametres/theme_manager.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        // Provider utilisateur
        ChangeNotifierProvider(create: (_) => UserProvider()),
        
        // Provider WebSocket
        ChangeNotifierProvider(create: (_) => WebSocketProvider()),
        
        // Provider salle/jeu
        ChangeNotifierProvider(create: (_) => RoomProvider()),
      ],
      child: const CaurisApp(),
    ),
  );
}

class CaurisApp extends StatelessWidget {
  const CaurisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ThemedApp(
      child: const HomePage(),
    );
  }
}
```

## 💻 Exemples d'utilisation

### Exemple 1 : Créer une salle

```dart
class CreateRoomPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final roomProvider = Provider.of<RoomProvider>(context);
    
    return Scaffold(
      body: ElevatedButton(
        onPressed: () async {
          final roomCode = await roomProvider.createRoom('Ma Salle', 2);
          if (roomCode != null) {
            Navigator.pushNamed(context, '/game-room');
          }
        },
        child: Text('Créer une salle'),
      ),
    );
  }
}
```

### Exemple 2 : Rejoindre une salle

```dart
class JoinRoomPage extends StatelessWidget {
  final TextEditingController _codeController = TextEditingController();
  
  @override
  Widget build(BuildContext context) {
    final roomProvider = Provider.of<RoomProvider>(context);
    
    return Scaffold(
      body: Column(
        children: [
          TextField(
            controller: _codeController,
            decoration: InputDecoration(labelText: 'Code de la salle'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await roomProvider.joinRoom(_codeController.text);
              if (success) {
                Navigator.pushNamed(context, '/game-room');
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Code invalide')),
                );
              }
            },
            child: Text('Rejoindre'),
          ),
        ],
      ),
    );
  }
}
```

### Exemple 3 : Utiliser WebSocket dans une partie

```dart
class GameRoomPage extends StatefulWidget {
  @override
  _GameRoomPageState createState() => _GameRoomPageState();
}

class _GameRoomPageState extends State<GameRoomPage> {
  StreamSubscription? _cardPlayedSubscription;

  @override
  void initState() {
    super.initState();
    _initializeWebSocket();
  }

  Future<void> _initializeWebSocket() async {
    final wsProvider = Provider.of<WebSocketProvider>(context, listen: false);
    
    // Se connecter
    await wsProvider.connect(serverUrl: 'ws://192.168.1.100:3000');
    
    // Écouter les cartes jouées
    _cardPlayedSubscription = wsProvider.wsService.onCardPlayed().listen((data) {
      print('Carte jouée: ${data['playerName']}');
      // Mettre à jour l'UI
      setState(() {});
    });
  }

  @override
  void dispose() {
    _cardPlayedSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roomProvider = Provider.of<RoomProvider>(context);
    final wsProvider = Provider.of<WebSocketProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Salle: ${roomProvider.currentRoomCode}'),
      ),
      body: wsProvider.isConnected
        ? GameBoard()
        : CircularProgressIndicator(),
    );
  }
}
```

## 📚 Pattern de développement

### Flux de données

```
Service (logique) → Provider (état) → Widget (UI)
```

### Règles d'utilisation

1. **Services** : Utilisés par les Providers, jamais directement par les Widgets
2. **Providers** : Utilisés par les Widgets pour l'état global
3. **Local State** : Utiliser `setState()` pour l'état local d'un widget

### Bonnes pratiques

1. Toujours accéder aux Services via `Provider.of(context, listen: false)` pour les opérations
2. Utiliser `Consumer` ou `Selector` pour reconstruire uniquement les parties nécessaires
3. Implémenter `dispose()` pour nettoyer les subscriptions
4. Gérer les erreurs dans les Providers

## 🐛 Dépannage

### Provider non trouvé

```dart
// Erreur : ProviderNotFoundException
// Solution : Vérifier que MultiProvider est configuré dans main.dart
```

### Service non initialisé

```dart
// Erreur : Service non disponible
// Solution : Utiliser UserService.instance, GameService.instance, etc.
```

### État non mis à jour

```dart
// Problème : L'UI ne se reconstruit pas
// Solution : Vérifier que notifyListeners() est appelé dans le Provider
```

## ✅ Checklist d'intégration

- [ ] Ajouter `provider` et `shared_preferences` dans `pubspec.yaml`
- [ ] Configurer `MultiProvider` dans `main.dart`
- [ ] Importer les providers dans les pages nécessaires
- [ ] Initialiser les connexions WebSocket dans les pages de jeu
- [ ] Gérer la déconnexion dans `dispose()`
- [ ] Tester les fonctionnalités

## 📖 Documentation supplémentaire

Pour plus d'informations sur les composants spécifiques :
- WebSocket : Voir `/opt/lampp/htdocs/backendCauris/WEBSOCKET_SETUP.md`
- Models : Voir les fichiers dans `lib/models/`
- Interfaces : Voir les pages dans `lib/interfaces/`

