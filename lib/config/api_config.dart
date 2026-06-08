/// Configuration de l'API Backend
///
/// URLs de production (Render) par défaut.
/// En développement local, surchargez au build :
///   flutter run --dart-define=BASE_URL=http://192.168.1.50:8000/api \
///               --dart-define=WEBSOCKET_URL=ws://192.168.1.50:3000
///
/// Test multijoueur 2 humains + 2 bots (APK release) :
///   flutter build apk --release --dart-define=ENABLE_TWO_HUMAN_TEST=true
class ApiConfig {
  /// API REST (Laravel)
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://backendcauris-41bd.onrender.com/api',
  );

  /// Serveur Socket.io (Node.js) — URL distincte de l'API REST
  static const String websocketUrl = String.fromEnvironment(
    'WEBSOCKET_URL',
    defaultValue: 'https://cauris-websocket-o4ow.onrender.com',
  );

  /// Obtenir l'URL complète d'un endpoint
  static String endpoint(String path) {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return '$base/$normalizedPath';
  }
}
