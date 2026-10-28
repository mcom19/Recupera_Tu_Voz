import 'package:flutter/material.dart';

/// Icono de "boca" para la pestaña "Labios" (comunicación por
/// movimiento labial). Usa el pictograma `assets/icons/labios.png`
/// (líneas sobre fondo transparente) mediante `ImageIcon`, que lo tiñe
/// con el color del `IconTheme` ambiente igual que un `Icon` normal:
/// así hereda el color de seleccionado/no seleccionado de la barra
/// inferior.
///
/// `filled` se mantiene por compatibilidad con la convención del resto
/// de iconos (contorno/relleno). El pictograma solo tiene versión de
/// contorno, así que en estado activo se dibuja un poco más grande.
class MouthIcon extends StatelessWidget {
  final bool filled;
  final double? size;
  final Color? color;

  const MouthIcon({super.key, this.filled = false, this.size, this.color});

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final base = size ?? iconTheme.size ?? 24;
    return ImageIcon(
      const AssetImage('assets/icons/labios.png'),
      size: filled ? base * 1.1 : base,
      color: color ?? iconTheme.color,
    );
  }
}
