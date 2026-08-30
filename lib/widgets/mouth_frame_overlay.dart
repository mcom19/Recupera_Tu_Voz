// lib/widgets/mouth_frame_overlay.dart
//
// Overlay visual que se coloca encima del CameraPreview: dibuja el
// óvalo-guía (igual que el actual lip_screen.dart) y lo colorea según
// el veredicto de FaceFramingService — sin intentar mapear el
// rectángulo de la boca detectado a coordenadas exactas de pantalla
// (ver comentario en face_framing_service.dart sobre por qué la
// decisión de encuadre vive solo en espacio de imagen).

import 'package:flutter/material.dart';

import '../services/face_framing_service.dart';

class MouthFrameOverlay extends StatelessWidget {
  final FramingState state;
  final bool recording;
  final Color colorBueno;
  final Color colorAjustando;
  final Color colorSinRostro;

  const MouthFrameOverlay({
    super.key,
    required this.state,
    required this.recording,
    required this.colorBueno,
    required this.colorAjustando,
    required this.colorSinRostro,
  });

  Color get _color {
    if (recording) return colorAjustando;
    switch (state.quality) {
      case FramingQuality.buena:
        return colorBueno;
      case FramingQuality.sinRostro:
        return colorSinRostro;
      case FramingQuality.muyLejos:
      case FramingQuality.muyCerca:
      case FramingQuality.descentrada:
        return colorAjustando;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Borde de todo el preview: feedback periférico, visible sin
          // mirar directamente al óvalo.
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                border: Border.all(color: _color.withValues(alpha: 0.9), width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          // Óvalo-guía de labios.
          Positioned(
            bottom: 40,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 130,
              height: 64,
              decoration: BoxDecoration(
                border: Border.all(color: _color, width: 3),
                borderRadius: BorderRadius.circular(64),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
