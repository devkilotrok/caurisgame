import 'package:flutter/material.dart';
import 'interfaces/home/home_page.dart';
import 'interfaces/parametres/theme_manager.dart';

void main() {
  runApp(const CaurisApp());
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

