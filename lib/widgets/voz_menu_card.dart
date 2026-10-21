import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Card de menú reutilizable — línea visual "azul profundo" de Proyecto
/// VOZ: mismo lenguaje que la AppBar (fondo azul marino, acentos claros),
/// pensada para listas de opciones (Ajustes, Perfil, Sesión,
/// Colaboradores, Práctica, y cualquier pantalla futura que necesite el
/// mismo tipo de fila navegable).
///
/// Toda la superficie es pulsable (no solo la flecha): usa `Material` +
/// `InkWell` respetando el `borderRadius`, con un feedback táctil sutil
/// (aclarado de fondo y borde, sin ripple llamativo ni zoom). Los colores
/// por defecto viven en `AppColors`/`AdaptiveColors` (no hardcoded aquí),
/// y se pueden sobrescribir por instancia (`iconColor`, `borderColor`,
/// `backgroundColor`/`gradient`, etc.) para variantes como la de "Clonar
/// mi voz" (que se mantiene con su propio estilo, fuera de este widget)
/// o [VozPrivacyCard] más abajo.
///
/// Pensada para pacientes con dificultades de comunicación: área táctil
/// grande, alto contraste, sin depender solo del color, y sin alturas
/// rígidas que puedan provocar overflow si el subtítulo ocupa más líneas
/// o el usuario escala el tamaño de letra del sistema.
class VozMenuCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final Color? borderColor;
  final Color? backgroundColor;
  final Gradient? gradient;
  final bool enabled;
  final EdgeInsetsGeometry? padding;
  final String? semanticLabel;

  const VozMenuCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.iconColor,
    this.iconBackgroundColor,
    this.borderColor,
    this.backgroundColor,
    this.gradient,
    this.enabled = true,
    this.padding,
    this.semanticLabel,
  });

  @override
  State<VozMenuCard> createState() => _VozMenuCardState();
}

class _VozMenuCardState extends State<VozMenuCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final interactive = widget.enabled && widget.onTap != null;

    final border = widget.borderColor ?? AppColors.cardBorder;
    final effectiveBorder = _pressed ? _brighten(border, 0.18) : border;

    // Fondo: gradiente por defecto (mismo azul profundo de la AppBar),
    // o el color/gradiente que pase la pantalla. Se aclara ligerísimamente
    // al pulsar, igual que el borde.
    Gradient? gradient;
    Color? solidColor;
    if (widget.gradient != null) {
      final g = widget.gradient!;
      gradient = (_pressed && g is LinearGradient)
          ? LinearGradient(
              begin: g.begin,
              end: g.end,
              stops: g.stops,
              colors: g.colors.map((c) => _brighten(c, 0.06)).toList(),
            )
          : g;
    } else if (widget.backgroundColor != null) {
      solidColor =
          _pressed ? _brighten(widget.backgroundColor!, 0.06) : widget.backgroundColor;
    } else {
      const start = AppColors.cardBgStart;
      const end = AppColors.cardBgEnd;
      gradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: _pressed
            ? [_brighten(start, 0.06), _brighten(end, 0.06)]
            : [start, end],
      );
    }

    final iconBg = widget.iconBackgroundColor ?? AppColors.cardIconBg;
    final iconColor = widget.iconColor ?? AppColors.cardIconContent;

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 130),
      curve: Curves.easeOut,
      constraints: const BoxConstraints(minHeight: 84),
      padding: widget.padding ??
          const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: solidColor,
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: effectiveBorder, width: 1),
        // Sombra extremadamente sutil y azulada; nada de negro puro ni
        // sombras grandes.
        boxShadow: const [
          BoxShadow(color: Color(0x140A1730), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Opacity(
        opacity: widget.enabled ? 1 : 0.45,
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(widget.icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: AppColors.cardTitle,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      widget.subtitle!,
                      style: const TextStyle(
                        color: AppColors.cardSubtitle,
                        fontSize: 14,
                        height: 1.25,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            widget.trailing ??
                (widget.onTap != null
                    ? const Icon(Icons.chevron_right_rounded,
                        size: 28, color: AppColors.cardChevron)
                    : const SizedBox.shrink()),
          ],
        ),
      ),
    );

    return Semantics(
      button: interactive,
      enabled: widget.enabled,
      label: widget.semanticLabel ?? widget.title,
      hint: widget.subtitle,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: interactive ? widget.onTap : null,
          onTapDown: interactive ? (_) => setState(() => _pressed = true) : null,
          onTapCancel: interactive ? () => setState(() => _pressed = false) : null,
          onTapUp: interactive ? (_) => setState(() => _pressed = false) : null,
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.white.withValues(alpha: 0.04),
          highlightColor: Colors.transparent,
          child: card,
        ),
      ),
    );
  }
}

Color _brighten(Color c, double amount) => Color.lerp(c, Colors.white, amount) ?? c;

/// Decoración de "card" reutilizable en cualquier contenedor de la app,
/// no solo en [VozMenuCard]: mismo fondo en gradiente azul profundo,
/// borde sutil y esquinas redondeadas — el mismo lenguaje visual, para
/// que un cuadro de texto, una fila de una lista o un aviso se vean
/// parte del mismo sistema.
///
/// Pásale `borderColor` cuando ese contenedor concreto deba seguir
/// señalando un estado con color (categoría de una frase, completado,
/// error, grabando...); el color de estado se mantiene y solo el fondo
/// y la esquina quedan en línea con el resto de cards.
BoxDecoration vozCardDecoration({
  double radius = 14,
  Color? borderColor,
  double borderWidth = 1,
  bool shadow = true,
}) {
  return BoxDecoration(
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppColors.cardBgStart, AppColors.cardBgEnd],
    ),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: borderColor ?? AppColors.cardBorder, width: borderWidth),
    boxShadow: shadow
        ? const [BoxShadow(color: Color(0x140A1730), blurRadius: 10, offset: Offset(0, 3))]
        : null,
  );
}

/// Variante lista para usar del mismo sistema visual, pensada para el
/// aviso de privacidad de la voz ("Tu voz es privada"): icono circular en
/// turquesa (en vez del azul del icono por defecto) y, a la derecha, un
/// enlace "Más información" + flecha en lugar de solo la flecha. Mismo
/// fondo azul profundo y mismas reglas de accesibilidad que [VozMenuCard],
/// del que está construida.
class VozPrivacyCard extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback? onMoreInfo;
  final String moreInfoLabel;

  const VozPrivacyCard({
    super.key,
    this.title = 'Tu voz es privada',
    this.description =
        'Solo se utiliza para generar tu voz dentro de la app. No se comparte con terceros.',
    this.onMoreInfo,
    this.moreInfoLabel = 'Más información',
  });

  @override
  Widget build(BuildContext context) {
    return VozMenuCard(
      icon: Icons.lock_rounded,
      title: title,
      subtitle: description,
      onTap: onMoreInfo,
      iconBackgroundColor: AppColors.cardAccentTurquesa.withValues(alpha: 0.16),
      iconColor: AppColors.cardAccentTurquesa,
      borderColor: AppColors.cardAccentTurquesa.withValues(alpha: 0.35),
      trailing: onMoreInfo == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  moreInfoLabel,
                  style: const TextStyle(
                    color: AppColors.cardAccentTurquesa,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Montserrat',
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded,
                    size: 22, color: AppColors.cardAccentTurquesa),
              ],
            ),
    );
  }
}
