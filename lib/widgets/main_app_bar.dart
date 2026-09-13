import 'package:flutter/material.dart';

/// AppBar compartida por toda la app: misma línea de diseño en todas
/// las pantallas — imagen de fondo (assets/images/appbar.png), un velo
/// oscuro sutil encima para garantizar contraste, contenido en blanco,
/// título a la izquierda. A la derecha siempre pueden aparecer dos
/// accesos directos ("Mi voz" y "Clases"), más las acciones propias que
/// cada pantalla necesite (extraActions).
///
/// - "Mi voz" recuerda clonar la voz mientras el paciente no la tenga
///   (icono con punto rojo) y da acceso directo a esa pantalla.
/// - "Clases" lleva a "Práctica", donde están las clases asignadas por
///   la logopeda. Ocúltalo con `showClasesAction: false` en la propia
///   pantalla de Práctica, para no enlazar una pantalla consigo misma.
///
/// El contenido se pinta en blanco (no en negro) porque la imagen de
/// fondo es mayoritariamente azul marino oscuro: el negro apenas se
/// leería sobre esa zona, mientras que el blanco se lee bien tanto
/// ahí como sobre la franja turquesa más clara de la imagen.
class MainAppBar extends StatelessWidget implements PreferredSizeWidget {
  static const String backgroundAsset = 'assets/images/appbar.png';
  static const Color foreground = Colors.white;

  final String title;
  final bool showVozAction;
  final bool vozPendiente;
  final VoidCallback? onVozTap;
  final bool showClasesAction;
  final VoidCallback? onClasesTap;
  final List<Widget>? extraActions;
  final Widget? leading;
  final bool automaticallyImplyLeading;

  const MainAppBar({
    super.key,
    required this.title,
    this.showVozAction = true,
    this.vozPendiente = false,
    this.onVozTap,
    this.showClasesAction = true,
    this.onClasesTap,
    this.extraActions,
    this.leading,
    this.automaticallyImplyLeading = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      foregroundColor: foreground,
      elevation: 0,
      centerTitle: false,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      flexibleSpace: const _AppBarBackground(),
      title: Text(
        title,
        style: const TextStyle(
          color: foreground,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          fontFamily: 'Montserrat',
        ),
      ),
      actions: [
        if (showVozAction)
          _AppBarShortcut(
            icon: vozPendiente ? Icons.mic_none_rounded : Icons.graphic_eq_rounded,
            label: 'VOZ',
            showDot: vozPendiente,
            onTap: onVozTap,
          ),
        if (showClasesAction)
          _AppBarShortcut(
            icon: Icons.assignment_rounded,
            label: 'CLASES',
            onTap: onClasesTap,
          ),
        if (extraActions != null) ...extraActions!,
        const SizedBox(width: 6),
      ],
    );
  }
}

/// Imagen de fondo + velo oscuro. Aislado en su propio widget const
/// para que Flutter no lo reconstruya innecesariamente.
class _AppBarBackground extends StatelessWidget {
  const _AppBarBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const Image(
          image: AssetImage(MainAppBar.backgroundAsset),
          fit: BoxFit.cover,
          // Antes: Alignment.center recortaba una franja intermedia de la
          // imagen y la onda turquesa quedaba "flotando" sin tocar ningún
          // borde. Alignment(0, 1) ancla el recorte al borde inferior
          // (evita el corte flotante) sin desplazarse hacia la derecha,
          // que es justo donde la onda es más brillante en este asset.
          alignment: Alignment(0, 1),
        ),
        // Velo oscuro sutil: asegura que el texto/iconos en blanco se
        // lean bien en cualquier zona de la imagen (incluida la franja
        // izquierda, más oscura, donde va el título).
        Container(color: Colors.black.withValues(alpha: 0.18)),
      ],
    );
  }
}

class _AppBarShortcut extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool showDot;
  final VoidCallback? onTap;

  const _AppBarShortcut({
    required this.icon,
    required this.label,
    this.showDot = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: MainAppBar.foreground, size: 21),
                if (showDot)
                  Positioned(
                    right: -3,
                    top: -3,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black.withValues(alpha: 0.35), width: 1),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: const TextStyle(
                color: MainAppBar.foreground,
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                fontFamily: 'Montserrat',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
