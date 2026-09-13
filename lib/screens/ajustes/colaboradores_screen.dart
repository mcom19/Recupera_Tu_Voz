import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/main_app_bar.dart';
import '../../widgets/voz_menu_card.dart';

/// Créditos y procedencia del proyecto. Bloque informativo: quién
/// impulsa la app y quién la financia, para que quien la recibe de su
/// logopeda sepa qué hay detrás. Sin acciones propias, solo lectura.
class ColaboradoresScreen extends StatelessWidget {
  final bool hasVoice;
  final VoidCallback onGoToVoz;
  final VoidCallback onGoToClases;
  const ColaboradoresScreen({
    super.key,
    required this.hasVoice,
    required this.onGoToVoz,
    required this.onGoToClases,
  });

  @override
  Widget build(BuildContext context) {
    final c = AdaptiveColors.of(context);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: MainAppBar(
        title: 'Colaboradores',
        vozPendiente: !hasVoice,
        onVozTap: onGoToVoz,
        onClasesTap: onGoToClases,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '"Recupera tu voz" es un proyecto para ayudar a personas '
            'laringectomizadas a comunicarse con su propia voz clonada. '
            'Nace en un centro educativo y se financia con una ayuda '
            'pública, sin ánimo de lucro.',
            style: TextStyle(color: c.textMid, fontSize: 13.5, height: 1.5),
          ),
          const SizedBox(height: 22),

          _EntidadCard(
            icon: Icons.school_outlined,
            nombre: 'Escuela Familiar Agraria El Campico',
            descripcion: 'Centro impulsor del proyecto',
            color: c.teal,
          ),
          const SizedBox(height: 12),
          _EntidadCard(
            icon: Icons.volunteer_activism_outlined,
            nombre: 'Ayudas Dualiza — Fundación Endesa',
            descripcion: 'Financiación del proyecto',
            color: c.gold,
          ),
          const SizedBox(height: 12),
          _EntidadCard(
            icon: Icons.handshake_outlined,
            nombre: 'Colaboración técnica',
            descripcion: 'Apoyo en el desarrollo e implantación',
            color: c.blue,
          ),

          const SizedBox(height: 26),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: vozCardDecoration(radius: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline_rounded, color: c.textMid, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tu voz se guarda de forma segura y solo se usa para '
                    'que la app hable con ella. No se comparte con '
                    'terceros ni se usa con ningún otro fin.',
                    style: TextStyle(color: c.textMid, fontSize: 12.5, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EntidadCard extends StatelessWidget {
  final IconData icon;
  final String nombre;
  final String descripcion;
  final Color color;

  const _EntidadCard({
    required this.icon,
    required this.nombre,
    required this.descripcion,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = AdaptiveColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: vozCardDecoration(radius: 12, borderColor: color.withValues(alpha: 0.3)),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            // Placeholder de logotipo: sustituir por el logo real de la
            // entidad (Image.asset) cuando esté disponible, manteniendo
            // este mismo texto como alternativa accesible.
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(descripcion, style: TextStyle(color: c.textMid, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
