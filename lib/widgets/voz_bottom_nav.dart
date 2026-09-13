import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Un ítem de [VozBottomNavigationBar].
///
/// [icon] y [activeIcon] son los mismos widgets de icono que ya se
/// usaban en el `BottomNavigationBar` de Material (p. ej. `Icon(...)` o
/// `MouthIcon(...)`) — no se han sustituido, solo se recolorean vía
/// [IconTheme] para que encajen con la paleta de la barra.
class VozBottomNavItem {
  final Widget icon;
  final Widget activeIcon;
  final String label;

  const VozBottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// Barra de navegación inferior propia de Proyecto VOZ.
///
/// Sustituye al `BottomNavigationBar` estándar de Material únicamente
/// en su presentación visual: la sección activa se reconoce mediante
/// una "pill" con superficie propia (fondo claro) alrededor del icono
/// y el label, no solo por un cambio de color de icono — un requisito
/// de accesibilidad para pacientes con dificultades de comunicación.
///
/// No contiene lógica de navegación ni de rutas: [currentIndex] y
/// [onTap] los sigue gestionando quien la usa (`AppShell` en
/// `main.dart`), exactamente igual que con el `BottomNavigationBar`
/// anterior. Se usa una única vez, en el `Scaffold` que envuelve el
/// `IndexedStack` de las 5 pestañas, así que el diseño se aplica de
/// forma consistente en toda la app sin duplicar el widget.
class VozBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<VozBottomNavItem> items;

  const VozBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final c = AdaptiveColors.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(color: c.navBarBg),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _VozNavTapArea(
                    item: items[i],
                    selected: i == currentIndex,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VozNavTapArea extends StatelessWidget {
  final VozBottomNavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _VozNavTapArea({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AdaptiveColors.of(context);

    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          child: ConstrainedBox(
            // Zona táctil cómoda (>= 48dp) aunque la "pill" visual sea
            // más pequeña: el área de toque ocupa todo el alto/ancho
            // de la columna de la barra, no solo la pill.
            constraints: const BoxConstraints(minHeight: 48),
            child: Center(
              child: ExcludeSemantics(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? c.navBarSelectedBg : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconTheme(
                        data: IconThemeData(color: c.navBarContent, size: 25),
                        child: selected ? item.activeIcon : item.icon,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.navBarContent,
                          fontSize: 11.5,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
