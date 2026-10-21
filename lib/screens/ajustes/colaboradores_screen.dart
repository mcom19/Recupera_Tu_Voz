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
            logoAsset: 'assets/logos/efa.png',
            nombre: 'EFA El Campico',
            categoria: 'Centro educativo',
            descripcion: 'Centro impulsor del proyecto. Desde EFA El '
                'Campico apostamos por una formación profesional '
                'conectada con la realidad y con impacto social.',
            color: AppColors.tealLight,
          ),
          const SizedBox(height: 12),
          _EntidadCard(
            logoAsset: 'assets/logos/logo_caixabankh.png',
            nombre: 'CaixaBank Dualiza',
            categoria: 'Financiación',
            descripcion: 'Convocatoria de Ayudas Dualiza. Este proyecto '
                'cuenta con el apoyo y la financiación de la '
                'convocatoria de ayudas de CaixaBank Dualiza, '
                'impulsando la innovación en la Formación Profesional.',
            color: AppColors.goldLight,
          ),
          const SizedBox(height: 12),
          _EntidadCard(
            logoAsset: 'assets/logos/fpempresa.png',
            nombre: 'FPEmpresas',
            categoria: 'Colaboración',
            descripcion: 'Impulso y acompañamiento. Contamos con la '
                'colaboración de FPEmpresas, asociando centros de '
                'Formación Profesional para impulsar proyectos '
                'innovadores y su conexión con el entorno social y '
                'empresarial.',
            color: AppColors.blueLight,
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
  final String logoAsset;
  // El logo ya lleva el nombre de la entidad dibujado (es un lockup
  // logo+texto, no un icono suelto): `nombre` no se muestra en
  // pantalla, solo se usa como etiqueta de accesibilidad del logo para
  // quien use un lector de pantalla.
  final String nombre;
  final String categoria;
  final String descripcion;
  final Color color;

  const _EntidadCard({
    required this.logoAsset,
    required this.nombre,
    required this.categoria,
    required this.descripcion,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // Fondo blanco fijo (no navy, a diferencia del resto de cards
        // de la app): los logotipos de las entidades están pensados
        // para fondo claro.
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.collabCardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            image: true,
            label: nombre,
            child: SizedBox(
              height: 56,
              width: double.infinity,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Image.asset(
                  logoAsset,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              categoria.toUpperCase(),
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            descripcion,
            style: const TextStyle(
              color: AppColors.textMidLight,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
