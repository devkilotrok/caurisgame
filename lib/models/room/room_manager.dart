import 'dart:convert';
import '../../services/api/payment_api_service.dart';

class RoomManager {
  static RoomManager? _instance;
  static RoomManager get instance => _instance ??= RoomManager._internal();
  
  RoomManager._internal();

  // Données du salon actuel
  String? _currentRoomId;
  String? _currentRoomName;
  String? _currentRoomCode;
  int? _currentMinimumBet;
  String? _creatorPseudo;
  DateTime? _roomCreationTime;
  bool _isRoomActive = false;
  List<Map<String, dynamic>> _players = [];

  // Fonction pour créer un salon
  Future<Map<String, dynamic>> createRoom({
    required String roomName,
    required int minimumBet,
    required String creatorPseudo,
  }) async {
    try {
      print('═══════════════════════════════════════════════');
      print('🔵 DÉBUT CRÉATION SALON');
      print('═══════════════════════════════════════════════');
      print('📝 Paramètres reçus :');
      print('   - Nom salon : $roomName');
      print('   - Mise minimum : $minimumBet');
      print('   - Créateur : $creatorPseudo');
      print('');
      
      // ✅ VÉRIFIER LE SOLDE AVANT DE CRÉER LE SALON
      print('🔍 Étape 1 : Vérification du solde...');
      final paymentService = PaymentApiService.instance;
      
      print('   → Appel de checkBalance avec requiredAmount: $minimumBet');
      final balanceCheck = await paymentService.checkBalance(requiredAmount: minimumBet);
      
      print('   → Réponse de checkBalance:');
      print('      success: ${balanceCheck['success']}');
      print('      hasEnough: ${balanceCheck['hasEnough']}');
      print('      balance: ${balanceCheck['balance']}');
      print('      message: ${balanceCheck['message']}');
      
      if (!balanceCheck['success']) {
        print('   ❌ ÉCHEC : balanceCheck échoué');
        print('═══════════════════════════════════════════════');
        return {
          'success': false,
          'message': balanceCheck['message'] ?? 'Erreur lors de la vérification du solde',
        };
      }
      
      if (balanceCheck['hasEnough'] == false) {
        final balance = balanceCheck['balance'] as int;
        final missing = minimumBet - balance;
        print('   ❌ ÉCHEC : Solde insuffisant');
        print('      - Solde actuel : $balance');
        print('      - Mise requise : $minimumBet');
        print('      - Manquant : $missing');
        print('═══════════════════════════════════════════════');
        return {
          'success': false,
          'message': 'Solde insuffisant. Vous avez $balance cauris, il vous manque $missing cauris.',
        };
      }
      
      print('   ✅ Solde suffisant');
      
      // Générer un code de salon unique
      print('');
      print('🔍 Étape 2 : Génération du code salon...');
      final roomCode = _generateRoomCode();
      print('   ✅ Code généré : $roomCode');

      // ✅ DÉBITER LE MONTANT
      print('');
      print('🔍 Étape 3 : Débit du montant...');
      final roomId = DateTime.now().millisecondsSinceEpoch;
      print('   → Appel de debitRoomBet');
      print('      amount: $minimumBet');
      print('      roomId: $roomId');
      
      final debitResult = await paymentService.debitRoomBet(
        amount: minimumBet,
        roomId: roomId,
      );
      
      print('   → Réponse de debitRoomBet:');
      print('      success: ${debitResult['success']}');
      print('      message: ${debitResult['message']}');
      print('      new_balance: ${debitResult['new_balance']}');
      
      if (!debitResult['success']) {
        print('   ❌ ÉCHEC : debitRoomBet échoué');
        print('═══════════════════════════════════════════════');
        return {
          'success': false,
          'message': debitResult['message'] ?? 'Erreur lors du débit',
        };
      }
      
      print('   ✅ Débit réussi');

      // Initialiser les données locales directement
      print('');
      print('🔍 Étape 4 : Initialisation des données locales...');
      _currentRoomId = 'simulated_room_${DateTime.now().millisecondsSinceEpoch}';
      _currentRoomName = roomName;
      _currentRoomCode = roomCode;
      _currentMinimumBet = minimumBet;
      _creatorPseudo = creatorPseudo;
      _roomCreationTime = DateTime.now();
      _isRoomActive = true;
      
      print('   → Room ID : $_currentRoomId');
      print('   → Room Name : $_currentRoomName');
      print('   → Room Code : $_currentRoomCode');
      print('   → Minimum Bet : $_currentMinimumBet');
      print('   → Creator : $_creatorPseudo');
      
      // Ajouter le créateur comme premier joueur
      _players = [
        {
          'pseudo': creatorPseudo,
          'position': 1,
          'isCreator': true,
          'joinedAt': DateTime.now().toIso8601String(),
          'status': 'ready',
        }
      ];
      
      print('   → Joueurs dans le salon : ${_players.length}');
      print('   ✅ Initialisation terminée');
      print('');
      print('✅ CRÉATION SALON RÉUSSIE !');
      print('═══════════════════════════════════════════════');

      return {
        'success': true,
        'roomId': _currentRoomId,
        'roomCode': roomCode,
        'message': 'Salon créé avec succès. Mise débitée: $minimumBet cauris',
        'newBalance': debitResult['new_balance'],
      };
    } catch (e, stackTrace) {
      print('');
      print('❌❌❌ EXCEPTION LORS DE LA CRÉATION ❌❌❌');
      print('Erreur : $e');
      print('Stack trace :');
      print(stackTrace);
      print('═══════════════════════════════════════════════');
      return {
        'success': false,
        'message': 'Erreur de connexion: ${e.toString()}',
      };
    }
  }

  // Fonction pour rejoindre un salon
  Future<Map<String, dynamic>> joinRoom({
    required String roomCode,
    required String playerPseudo,
  }) async {
    try {
      print('=== REJOINDRE SALON AVEC PAIEMENT ===');
      print('Code: $roomCode');
      print('Joueur: $playerPseudo');
      print('===============================');

      // Simuler la récupération des données du salon
      final roomData = {
        'roomId': 'simulated_room_$roomCode',
        'roomName': 'Room $roomCode',
        'minimumBet': 50,
        'creatorPseudo': 'Lewis',
        'playerCount': 1,
      };

      final minimumBet = roomData['minimumBet'] as int;
      
      // ✅ VÉRIFIER LE SOLDE AVANT DE REJOINDRE
      final paymentService = PaymentApiService.instance;
      final balanceCheck = await paymentService.checkBalance(requiredAmount: minimumBet);
      
      if (!balanceCheck['success']) {
        return {
          'success': false,
          'message': balanceCheck['message'] ?? 'Erreur lors de la vérification du solde',
        };
      }
      
      if (balanceCheck['hasEnough'] == false) {
        final balance = balanceCheck['balance'] as int;
        final missing = minimumBet - balance;
        return {
          'success': false,
          'message': 'Solde insuffisant. Vous avez $balance cauris, il vous manque $missing cauris.',
        };
      }
      
      // ✅ DÉBITER LE MONTANT
      final roomIdInt = int.tryParse(roomCode.substring(3)) ?? DateTime.now().millisecondsSinceEpoch;
      final debitResult = await paymentService.debitRoomBet(
        amount: minimumBet,
        roomId: roomIdInt,
      );
      
      if (!debitResult['success']) {
        return {
          'success': false,
          'message': debitResult['message'] ?? 'Erreur lors du débit',
        };
      }

      // Mettre à jour les données locales
      _currentRoomId = roomData['roomId'] as String;
      _currentRoomName = roomData['roomName'] as String;
      _currentRoomCode = roomCode;
      _currentMinimumBet = minimumBet;
      _creatorPseudo = roomData['creatorPseudo'] as String;
      _isRoomActive = true;

      // Ajouter le joueur à la liste locale
      _players.add({
        'pseudo': playerPseudo,
        'position': (roomData['playerCount'] as int) + 1,
        'isCreator': false,
        'joinedAt': DateTime.now().toIso8601String(),
        'status': 'ready',
      });

      // Vérifier si le salon est plein pour démarrer la partie
      if (_players.length >= 4) {
        await _startGame();
      }

      return {
        'success': true,
        'roomId': _currentRoomId,
        'roomName': _currentRoomName,
        'roomCode': roomCode,
        'minimumBet': _currentMinimumBet,
        'creatorPseudo': _creatorPseudo,
        'message': 'Joueur ajouté au salon avec succès. Mise débitée: $minimumBet cauris',
        'newBalance': debitResult['new_balance'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erreur lors de l\'ajout du joueur: ${e.toString()}',
      };
    }
  }

  // Fonction pour démarrer le jeu
  Future<void> _startGame() async {
    print('=== DÉMARRAGE DU JEU ===');
    print('Nombre de joueurs: ${_players.length}');
    print('========================');
    
    // Marquer tous les joueurs comme prêts
    for (var player in _players) {
      player['status'] = 'playing';
    }
  }

  // Fonction pour obtenir les informations du salon actuel
  Map<String, dynamic>? getCurrentRoomInfo() {
    if (!_isRoomActive) return null;
    
    return {
      'roomId': _currentRoomId,
      'roomName': _currentRoomName,
      'roomCode': _currentRoomCode,
      'minimumBet': _currentMinimumBet,
      'creatorPseudo': _creatorPseudo,
      'playerCount': _players.length,
      'players': List.from(_players),
      'isActive': _isRoomActive,
    };
  }

  // Fonction pour obtenir la liste des joueurs
  List<Map<String, dynamic>> getPlayers() {
    return List.from(_players);
  }

  // Fonction pour quitter le salon
  Future<Map<String, dynamic>> leaveRoom(String playerPseudo) async {
    try {
      if (_currentRoomId == null) {
        return {
          'success': false,
          'message': 'Aucun salon actif',
        };
      }

      // Retirer le joueur de la liste
      _players.removeWhere((player) => player['pseudo'] == playerPseudo);
      
      print('=== SIMULATION QUITTER SALON ===');
      print('Joueur: $playerPseudo');
      print('Joueurs restants: ${_players.length}');
      print('===============================');

      // Si c'est le créateur qui part, fermer le salon
      if (_creatorPseudo == playerPseudo) {
        await closeRoom();
      }

      return {
        'success': true,
        'message': 'Joueur retiré du salon',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erreur lors de la sortie du salon: ${e.toString()}',
      };
    }
  }

  // Fonction pour fermer le salon
  Future<void> closeRoom() async {
    print('=== FERMETURE DU SALON ===');
    print('Salon fermé par le créateur');
    print('==========================');
    
    // Réinitialiser les données locales
    _currentRoomId = null;
    _currentRoomName = null;
    _currentRoomCode = null;
    _currentMinimumBet = null;
    _creatorPseudo = null;
    _roomCreationTime = null;
    _isRoomActive = false;
    _players.clear();
  }

  // Fonction pour générer un code de salon unique
  String _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    final code = StringBuffer();
    
    for (int i = 0; i < 6; i++) {
      code.write(chars[(random + i) % chars.length]);
    }
    
    return code.toString();
  }

  // Getters
  String? get currentRoomId => _currentRoomId;
  String? get currentRoomName => _currentRoomName;
  String? get currentRoomCode => _currentRoomCode;
  int? get currentMinimumBet => _currentMinimumBet;
  String? get creatorPseudo => _creatorPseudo;
  bool get isRoomActive => _isRoomActive;
  int get playerCount => _players.length;
}