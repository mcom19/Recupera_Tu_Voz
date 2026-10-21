import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Estado que representa [VozConnectionStatusCard].
enum VozConnectionState {
  /// Sin conexión: icono de wifi con el indicativo rojo.
  offline,

  /// Reintentando conectar: indicador de carga en vez del icono.
  reconnecting,
}

/// Aviso de estado de conexión, reutilizable en toda la app (p. ej.
/// "usando el catálogo básico sin conexión" en Frases).
///
/// Sigue la línea visual del sistema de componentes de Proyecto VOZ:
/// superficie translúcida con borde sutil, sin degradados ni efectos
/// llamativos, para que destaque sobre el fondo azul noche sin
/// competir con el resto de la interfaz. Los colores vienen siempre de
/// [AppColors]/[AdaptiveColors], nunca hardcodeados aquí.
///
/// Pensado para mostrarse como `content` de un `SnackBar` flotante —
/// usa [showVozConnectionSnackBar] más abajo — para heredar su
/// posicionamiento (encima del `BottomNavigationBar`) y su ciclo de
/// vida (cola, auto-dismiss) sin tener que reimplementarlo pantalla a
/// pantalla.
class VozConnectionStatusCard extends StatelessWidget {
  final String message;
  final VozConnectionState state;

  /// Si se indican ambos, toda la card se vuelve táctil (zona de toque
  /// amplia) y muestra [actionLabel] como acción de texto. Si se omite
  /// alguno, la card queda en su variación "sin acción" (solo
  /// informativa).
  final String? actionLabel;
  final VoidCallback? onAction;

  const VozConnectionStatusCard({
    super.key,
    required this.message,
    this.state = VozConnectionState.offline,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final c = AdaptiveColors.of(context);
    final hasAction = actionLabel != null && onAction != null;

    final card = Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: c.statusCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.statusCardBorder, width: 1),
      ),
      child: Row(
        children: [
          _StatusIcon(state: state, c: c),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (hasAction) ...[
            const SizedBox(width: 12),
            Text(
              actionLabel!,
              style: TextStyle(
                color: c.statusCardAction,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );

    final semanticLabel = hasAction ? '$message. $actionLabel' : message;

    if (!hasAction) {
      return Semantics(
        container: true,
        liveRegion: true,
        label: semanticLabel,
        child: card,
      );
    }

    // Toda la superficie es táctil (no solo el texto "Reintentar"),
    // para una zona de toque amplia; el propio InkWell aporta el
    // feedback discreto al presionar (variación "Al presionar" del
    // diseño), sin glow ni animaciones llamativas.
    return Semantics(
      container: true,
      liveRegion: true,
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onAction,
          borderRadius: BorderRadius.circular(14),
          splashColor: c.statusCardBorder,
          highlightColor: c.statusCardBorder,
          child: card,
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final VozConnectionState state;
  final AdaptiveColors c;

  const _StatusIcon({required this.state, required this.c});

  @override
  Widget build(BuildContext context) {
    if (state == VozConnectionState.reconnecting) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: c.statusCardLoading,
        ),
      );
    }

    return SizedBox(
      width: 20,
      height: 20,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.wifi_rounded, size: 20, color: c.statusCardIcon),
          Positioned(
            left: -1,
            bottom: -1,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: c.statusCardOfflineDot,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Muestra [VozConnectionStatusCard] como un `SnackBar` flotante para
/// que aparezca justo encima del `BottomNavigationBar`, igual que
/// hacía el `SnackBar` estándar que sustituye. No cambia cuándo se
/// dispara el aviso (eso lo decide cada pantalla), solo su
/// presentación visual.
void showVozConnectionSnackBar(
  BuildContext context, {
  required String message,
  VozConnectionState state = VozConnectionState.offline,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 4),
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: VozConnectionStatusCard(
        message: message,
        state: state,
        actionLabel: actionLabel,
        onAction: onAction == null
            ? null
            : () {
                messenger.hideCurrentSnackBar();
                onAction();
              },
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      duration: duration,
    ),
  );
}
