import 'package:flutter/material.dart';

/// Icono de "boca" para la pestaña "Labios" (comunicación por
/// movimiento labial). Material Icons no incluye un pictograma de
/// boca, así que se dibuja a mano con CustomPainter en vez de añadir
/// una librería de iconos nueva solo para uno.
///
/// Sigue la misma convención que el resto de iconos de la barra
/// inferior: contorno cuando la pestaña no está seleccionada
/// (`filled: false`), relleno cuando sí (`filled: true`). El color y el
/// tamaño se toman del `IconTheme` ambiente igual que un `Icon` normal,
/// así que hereda automáticamente el color de seleccionado/no
/// seleccionado del `BottomNavigationBar`.
class MouthIcon extends StatelessWidget {
  final bool filled;
  final double? size;
  final Color? color;

  const MouthIcon({super.key, this.filled = false, this.size, this.color});

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final effectiveSize = size ?? iconTheme.size ?? 24;
    final effectiveColor = color ?? iconTheme.color ?? Colors.black;
    return SizedBox(
      width: effectiveSize,
      height: effectiveSize,
      child: CustomPaint(
        painter: _MouthPainter(filled: filled, color: effectiveColor),
      ),
    );
  }
}

class _MouthPainter extends CustomPainter {
  final bool filled;
  final Color color;
  const _MouthPainter({required this.filled, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Óvalo aplanado = boca; una línea curva en el centro sugiere el
    // cierre de los labios, para que se lea como boca y no como un
    // círculo cualquiera incluso a tamaño pequeño (24px).
    final rect = Rect.fromLTWH(
      size.width * 0.08,
      size.height * 0.30,
      size.width * 0.84,
      size.height * 0.40,
    );
    final strokeWidth = size.shortestSide * 0.11;

    final seam = Path()
      ..moveTo(rect.left + rect.width * 0.10, rect.center.dy)
      ..quadraticBezierTo(
        rect.center.dx,
        rect.center.dy + rect.height * 0.35,
        rect.right - rect.width * 0.10,
        rect.center.dy,
      );

    if (filled) {
      canvas.drawOval(rect, Paint()..color = color..style = PaintingStyle.fill);
      canvas.drawPath(
        seam,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.32)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth * 0.55
          ..strokeCap = StrokeCap.round,
      );
    } else {
      canvas.drawOval(
        rect,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
      );
      canvas.drawPath(
        seam,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth * 0.75
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MouthPainter oldDelegate) =>
      oldDelegate.filled != filled || oldDelegate.color != color;
}
