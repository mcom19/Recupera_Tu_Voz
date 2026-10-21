// lib/screens/panel/logopeda_videos_screen.dart
//
// Vídeos — pendiente de implementar storage (S3 / Firebase Storage).
// Muestra un estado claro con instrucciones.

import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../theme/app_theme.dart';
import '../../widgets/main_app_bar.dart';

class LogopedaVideosScreen extends StatelessWidget {
  final AppUser user;
  const LogopedaVideosScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final c = AdaptiveColors.of(context);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: MainAppBar(title: 'Vídeos', showVozAction: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: c.purple.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.video_library_outlined, color: c.purple, size: 36),
            ),
            const SizedBox(height: 20),
            Text('Vídeos de guía',
                style: TextStyle(color: c.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(
              'Podrás subir vídeos demostrativos para tus fichas y ejercicios. '
                  'Requiere configurar almacenamiento (S3 o Firebase Storage).',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textDim, fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tipos de vídeo planificados:',
                      style: TextStyle(color: c.textMid, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  ...[
                    ('Demo de ejercicio', Icons.fitness_center_rounded, c.accent),
                    ('Clase por nivel', Icons.school_rounded, c.teal),
                    ('General / informativo', Icons.info_outline_rounded, c.gold),
                    ('Paciente modelo', Icons.record_voice_over_rounded, c.purple),
                  ].map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(item.$2, color: item.$3, size: 16),
                        const SizedBox(width: 8),
                        Text(item.$1, style: TextStyle(color: c.textPrimary, fontSize: 13)),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}