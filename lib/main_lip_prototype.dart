// lib/main_lip_prototype.dart
//
// Punto de entrada AISLADO solo para probar el prototipo de encuadre +
// captura de lectura de labios, sin tocar el main.dart ni el
// app_router.dart de la app final. Se ejecuta con:
//
//   flutter run -t lib/main_lip_prototype.dart
//
// Cuando el prototipo esté validado, la integración real es sustituir
// (o añadir junto a) `LipScreen` en app_router.dart por
// `LipCapturePrototypeScreen`, pasándole el mismo `AppUser` — no hace
// falta cambiar nada de este archivo, es solo un arnés de pruebas.

import 'package:flutter/material.dart';

import 'screens/lip_capture_prototype_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const _LipPrototypeApp());
}

class _LipPrototypeApp extends StatelessWidget {
  const _LipPrototypeApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prototipo — Lectura de labios',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      // Sin AppUser: se prueba en modo demo local (ver
      // LipCapturePrototypeScreen._enviarABackend, que cae a modo demo
      // si no hay backend o si el usuario es null/sin token válido).
      home: const LipCapturePrototypeScreen(user: null),
    );
  }
}
