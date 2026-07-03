class GameSession {
  static GameSession? _instance;
  static GameSession get instance => _instance ??= GameSession._internal();
  
  GameSession._internal();

  // Données de la session de jeu
  String? roomId;
  String? roomName;
  String? roomCode;
  int? minimumBet;
  DateTime? startTime;
  DateTime? endTime;
  String? winnerName;
  int? winnerScore;
  
  // Liste des joueurs dans l'ordre d'arrivée
  List<Map<String, dynamic>> players = [];
  
  // Données des rondes
  List<Map<String, dynamic>> roundsData = [];
  
  // Scores globaux actuels
  List<double> globalScores = [];
  
  // État de la partie
  bool isGameActive = false;
  bool isGameCompleted = false;
  int currentRound = 0;
  bool playWithBots = false;
  bool alreadyJoined = false;
  
  // Fonction pour initialiser une nouvelle session
  void initializeSession({
    required String roomId,
    required String roomName,
    required String roomCode,
    required int minimumBet,
    required List<Map<String, dynamic>> players,
  }) {
    this.roomId = roomId;
    this.roomName = roomName;
    this.roomCode = roomCode;
    this.minimumBet = minimumBet;
    this.players = List.from(players);
    this.startTime = DateTime.now();
    this.endTime = null;
    this.winnerName = null;
    this.winnerScore = null;
    this.roundsData = [];
    this.globalScores = List.filled(players.length, 0.0);
    this.isGameActive = true;
    this.isGameCompleted = false;
    this.currentRound = 0;
    this.playWithBots = false;
    this.alreadyJoined = false;
  }
  
  // Fonction pour ajouter le round actuel (sans incrémenter currentRound)
  // Utilisée après announcements_complete pour ajouter le round qui vient de terminer ses annonces
  void addCurrentRound(List<int> announcements) {
    if (!isGameActive) return;
    
    // Vérifier si le round actuel existe déjà
    final existingRound = roundsData.any((r) => (r['roundNumber'] as int) == currentRound);
    
    if (existingRound) {
      print('⚠️ Round $currentRound existe déjà - évitement du doublon');
      return; // Ne pas ajouter de doublon
    }
    
    // Ajouter le round actuel sans incrémenter currentRound
    roundsData.add({
      'roundNumber': currentRound,
      'announcements': List<int>.from(announcements),
      'results': List.filled(announcements.length, null),
      'isCompleted': false,
      'timestamp': DateTime.now(),
    });
    
    print('✅ Round $currentRound ajouté (sans incrément) avec annonces: $announcements');
  }

  /// Met à jour les annonces du round en cours (ex. ajustement backend +1).
  void updateCurrentRoundAnnouncements(List<int> announcements) {
    if (!isGameActive) return;

    for (var i = 0; i < roundsData.length; i++) {
      if ((roundsData[i]['roundNumber'] as int) == currentRound) {
        roundsData[i]['announcements'] = List<int>.from(announcements);
        print('✅ Round $currentRound mis à jour avec annonces: $announcements');
        return;
      }
    }

    addCurrentRound(announcements);
  }

  // Fonction pour ajouter une nouvelle ronde (incrémente currentRound)
  // Utilisée pour préparer le round suivant avant de commencer ses annonces
  void addRound(List<int> announcements) {
    if (!isGameActive) return;
    
    // ✅ Vérifier si une ronde avec le même numéro existe déjà (éviter les doublons)
    // IMPORTANT: Vérifier AVANT d'incrémenter currentRound pour éviter les conditions de course
    final nextRoundNumber = currentRound + 1;
    final existingRound = roundsData.any((r) => (r['roundNumber'] as int) == nextRoundNumber);
    
    if (existingRound) {
      print('⚠️ Round $nextRoundNumber existe déjà - évitement du doublon');
      return; // Ne pas ajouter de doublon
    }
    
    // ✅ Double vérification: s'assurer qu'on n'ajoute pas un round qui existe déjà
    // (protection contre les conditions de course)
    if (roundsData.isNotEmpty) {
      final lastRound = roundsData.last;
      final lastRoundNumber = (lastRound['roundNumber'] as int? ?? 0);
      if (lastRoundNumber >= nextRoundNumber) {
        print('⚠️ Round $nextRoundNumber existe déjà (vérification finale) - évitement du doublon');
        return;
      }
    }
    
    // Incrémenter et ajouter seulement si toutes les vérifications passent
    currentRound++;
    roundsData.add({
      'roundNumber': currentRound,
      'announcements': List<int>.from(announcements),
      'results': List.filled(announcements.length, null),
      'isCompleted': false,
      'timestamp': DateTime.now(),
    });
    
    print('✅ Round $currentRound ajouté avec annonces: $announcements');
  }
  
  // Fonction pour finaliser un round
  void finalizeRound(int roundIndex, List<int> obtainedTricks) {
    if (!isGameActive || roundIndex >= roundsData.length) return;
    
    final round = roundsData[roundIndex];
    final announcements = round['announcements'] as List<int>;
    final results = <double>[];
    
    // Calculer les résultats pour chaque joueur (score du round uniquement, pas cumulatif)
    for (int playerIndex = 0; playerIndex < announcements.length; playerIndex++) {
      final announced = announcements[playerIndex];
      final obtained = obtainedTricks[playerIndex];
      
      // Calculer uniquement le score de ce round (sans cumul)
      final roundScore = _calculateRoundScore(announced, obtained);
      results.add(roundScore);
    }
    
    // Mettre à jour le round
    roundsData[roundIndex]['results'] = results;
    roundsData[roundIndex]['isCompleted'] = true;
    roundsData[roundIndex]['obtainedTricks'] = List.from(obtainedTricks);
    
    // Mettre à jour les scores globaux (cumul de tous les rounds)
    _updateGlobalScores();
    
    // Vérifier la fin de partie
    _checkGameEnd();
  }
  
  // Fonction pour calculer le score d'un round uniquement (sans cumul)
  double _calculateRoundScore(int announced, int obtained) {
    if (announced == obtained) {
      // Règle 1: Plis obtenus = Plis annoncés
      return announced * 10.0;
    } else if (obtained < announced) {
      // Règle 2: Plis obtenus < Plis annoncés
      return -(announced * 10.0);
    } else if (obtained > announced && obtained <= announced + 2) {
      // Règle 3: Plis obtenus > Plis annoncés (1 ou 2 plis en plus)
      final surplus = obtained - announced;
      return (announced * 10.0) + surplus;
    } else if (obtained >= announced + 3) {
      // Règle 4: Plis obtenus ≥ Plis annoncés + 3
      return -(announced * 10.0);
    }
    
    return 0.0; // Cas par défaut
  }
  
  // Fonction pour mettre à jour les scores globaux
  void _updateGlobalScores() {
    for (int playerIndex = 0; playerIndex < players.length; playerIndex++) {
      double totalScore = 0.0;
      for (var round in roundsData) {
        final results = round['results'] as List<double?>;
        if (results[playerIndex] != null) {
          totalScore += (results[playerIndex] as double);
        }
      }
      globalScores[playerIndex] = totalScore;
    }
  }
  
  // Fonction pour vérifier la fin de partie
  void _checkGameEnd() {
    for (int i = 0; i < globalScores.length; i++) {
      if (globalScores[i] >= 150) {
        endGame(players[i]['name'] as String, globalScores[i].toInt());
        break;
      }
    }
  }
  
  // Fonction pour terminer la partie
  void endGame(String winnerName, int winnerScore) {
    this.winnerName = winnerName;
    this.winnerScore = winnerScore;
    this.endTime = DateTime.now();
    this.isGameActive = false;
    this.isGameCompleted = true;
  }
  
  // Fonction pour obtenir les données à sauvegarder
  Map<String, dynamic> getGameData() {
    return {
      'roomId': roomId,
      'roomName': roomName,
      'roomCode': roomCode,
      'minimumBet': minimumBet,
      'startTime': startTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'duration': endTime != null && startTime != null 
          ? endTime!.difference(startTime!).inMinutes 
          : null,
      'winnerName': winnerName,
      'winnerScore': winnerScore,
      'players': players,
      'roundsData': roundsData,
      'finalScores': globalScores,
      'totalRounds': roundsData.length,
      'isCompleted': isGameCompleted,
    };
  }
  
  // Fonction pour sauvegarder dans la base de données
  Future<void> saveToDatabase() async {
    if (!isGameCompleted) return;
    
    final gameData = getGameData();
    
    // TODO: Implémenter la sauvegarde en base de données
    // Exemple avec une API ou une base de données locale
    print('Sauvegarde de la partie: $gameData');
    
    // Ici vous pouvez ajouter votre logique de sauvegarde
    // Par exemple avec Firebase, SQLite, ou une API REST
  }
  
  // Fonction pour réinitialiser la session
  void reset() {
    _instance = null;
  }
  
  // Fonction pour obtenir le tableau de score actuel
  List<Map<String, dynamic>> getScoreTable() {
    return roundsData.map((round) {
      final roundNumber = round['roundNumber'] as int;
      final announcements = round['announcements'] as List<int>;
      final results = round['results'] as List<double?>;
      final isCompleted = round['isCompleted'] as bool;
      
      return {
        'round': 'R$roundNumber',
        'data': isCompleted ? results : announcements,
        'isCompleted': isCompleted,
      };
    }).toList();
  }
  
  // Fonction pour obtenir les informations du salon
  Map<String, dynamic> getRoomInfo() {
    return {
      'roomName': roomName,
      'roomCode': roomCode,
      'minimumBet': minimumBet,
      'playerCount': players.length,
      'currentRound': currentRound,
      'isActive': isGameActive,
    };
  }
}
