import 'package:flutter/material.dart';
import '../services/user/user_service.dart';
import '../services/storage/storage_service.dart';

/// Provider pour la gestion de l'utilisateur et de l'authentification
class UserProvider extends ChangeNotifier {
  final UserService _userService = UserService.instance;
  final StorageService _storageService = StorageService.instance;

  bool _isLoggedIn = false;
  String? _currentUserPseudo;
  String? _currentUserEmail;

  bool get isLoggedIn => _isLoggedIn;
  String? get currentUserPseudo => _currentUserPseudo;
  String? get currentUserEmail => _currentUserEmail;

  UserProvider() {
    _checkLoginStatus();
  }

  /// Vérifier le statut de connexion au démarrage
  Future<void> _checkLoginStatus() async {
    final pseudo = await _storageService.getString('user_pseudo');
    final email = await _storageService.getString('user_email');

    if (pseudo != null && email != null) {
      _currentUserPseudo = pseudo;
      _currentUserEmail = email;
      _isLoggedIn = true;
      _userService.login(pseudo, email);
      notifyListeners();
    }
  }

  /// Se connecter
  Future<void> login(String pseudo, String email) async {
    _userService.login(pseudo, email);
    _currentUserPseudo = pseudo;
    _currentUserEmail = email;
    _isLoggedIn = true;

    // Sauvegarder dans le stockage local
    await _storageService.saveString('user_pseudo', pseudo);
    await _storageService.saveString('user_email', email);

    notifyListeners();
  }

  /// Se déconnecter
  Future<void> logout() async {
    _userService.logout();
    _currentUserPseudo = null;
    _currentUserEmail = null;
    _isLoggedIn = false;

    // Supprimer du stockage local
    await _storageService.remove('user_pseudo');
    await _storageService.remove('user_email');

    notifyListeners();
  }
}

