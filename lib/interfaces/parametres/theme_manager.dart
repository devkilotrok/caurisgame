import 'package:flutter/material.dart';

// Classe pour gérer le thème global
class ThemeManager {
  static const String _themeKey = 'selected_theme';
  
  // Obtenir le thème actuel
  static String getCurrentTheme() {
    // Pour l'instant, on retourne 'Sombre' par défaut
    // Dans une vraie app, on utiliserait SharedPreferences
    return 'Sombre';
  }
  
  // Sauvegarder le thème sélectionné
  static Future<void> saveTheme(String theme) async {
    // Dans une vraie app, on sauvegarderait avec SharedPreferences
    print('Thème sauvegardé: $theme');
  }
  
  // Obtenir le ThemeData selon le thème sélectionné
  static ThemeData getThemeData(String theme) {
    if (theme == 'Clair') {
      return ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF228B22), // Vert plus foncé
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
      );
    } else {
      // Mode Sombre (par défaut)
      return ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF228B22), // Vert plus foncé
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      );
    }
  }
}

// Widget pour gérer le thème dynamique
class ThemedApp extends StatefulWidget {
  final Widget child;
  
  const ThemedApp({super.key, required this.child});
  
  @override
  State<ThemedApp> createState() => _ThemedAppState();
  
  // Méthode pour changer le thème depuis n'importe où
  static void updateTheme(BuildContext context, String theme) {
    final state = context.findAncestorStateOfType<_ThemedAppState>();
    if (state != null) {
      state.changeTheme(theme);
    }
  }
}

class _ThemedAppState extends State<ThemedApp> {
  String _currentTheme = ThemeManager.getCurrentTheme();
  
  void changeTheme(String newTheme) {
    setState(() {
      _currentTheme = newTheme;
    });
    ThemeManager.saveTheme(newTheme);
  }
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CAURIS DEGUE',
      theme: ThemeManager.getThemeData(_currentTheme),
      home: widget.child,
      debugShowCheckedModeBanner: false,
    );
  }
}


