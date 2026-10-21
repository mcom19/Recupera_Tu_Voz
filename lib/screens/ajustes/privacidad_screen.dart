import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/main_app_bar.dart';
import '../../widgets/voz_menu_card.dart';

/// Detalle del aviso de privacidad de la voz, al que lleva "Más
/// información" desde la card VozPrivacyCard en Ajustes. Solo
/// informativa, sin acciones propias (mismo patrón que Colaboradores).
class PrivacidadScreen extends StatelessWidget {
  final bool hasVoice;
  final VoidCallback onGoToVoz;
  final VoidCallback onGoToClases;

  const PrivacidadScreen({
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
        title: 'Privacidad',
        vozPendiente: !hasVoice,
        onVozTap: onGoToVoz,
        onClasesTap: onGoToClases,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: c.cardAccentTurquesa.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lock_rounded, color: c.cardAccentTurquesa, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            'Tu voz es privada',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Solo se utiliza para generar tu voz dentro de la app. No se '
            'comparte con terceros.',
            style: TextStyle(color: c.textMid, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 26),

          _InfoBlock(
            icon: Icons.mic_none_rounded,
            titulo: 'Qué guardamos',
            texto: 'La grabación que subes al clonar tu voz, y el modelo de '
                'voz que se genera a partir de ella para que la app pueda '
                'hablar con tu propio tono.',
          ),
          const SizedBox(height: 16),
          _InfoBlock(
            icon: Icons.record_voice_over_rounded,
            titulo: 'Para qué se usa',
            texto: 'Únicamente para que "Frases", "Escribir" y "Práctica" '
                'hablen con tu voz clonada en lugar de la voz genérica del '
                'dispositivo.',
          ),
          const SizedBox(height: 16),
          _InfoBlock(
            icon: Icons.block_rounded,
            titulo: 'Qué no hacemos',
            texto: 'No compartimos tu voz ni tus grabaciones con terceros, '
                'ni las usamos con ningún otro fin distinto al de esta app.',
          ),

          const SizedBox(height: 26),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: vozCardDecoration(radius: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: c.textMid, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Si tienes dudas sobre tu voz o tus datos, puedes '
                    'consultarlo con tu logopeda, vinculado en la pantalla '
                    'de Sesión.',
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

class _InfoBlock extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String texto;

  const _InfoBlock({required this.icon, required this.titulo, required this.texto});

  @override
  Widget build(BuildContext context) {
    final c = AdaptiveColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: c.cardAccentTurquesa, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(texto, style: TextStyle(color: c.textMid, fontSize: 13, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}
