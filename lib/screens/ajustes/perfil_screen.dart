import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../theme/app_theme.dart';
import '../../widgets/main_app_bar.dart';
import '../../widgets/voz_menu_card.dart';

/// Datos de cuenta: nombre, correo y logopeda vinculado. Pantalla
/// informativa, de consulta poco frecuente — las acciones sobre la
/// sesión (desvincular, cerrar sesión) viven en la pantalla "Sesión".
class PerfilScreen extends StatelessWidget {
  final AppUser user;
  final VoidCallback onGoToVoz;
  final VoidCallback onGoToClases;
  const PerfilScreen({
    super.key,
    required this.user,
    required this.onGoToVoz,
    required this.onGoToClases,
  });

  @override
  Widget build(BuildContext context) {
    final c = AdaptiveColors.of(context);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: MainAppBar(
        title: 'Perfil',
        vozPendiente: !user.hasVoice,
        onVozTap: onGoToVoz,
        onClasesTap: onGoToClases,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: vozCardDecoration(radius: 14),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: c.accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person_rounded, color: c.accent, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name.isEmpty ? 'Sin nombre' : user.name,
                        style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(user.email, style: TextStyle(color: c.textMid, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (user.isPatient && user.logopedaId != null && user.logopedaId!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: vozCardDecoration(radius: 10),
              child: Row(
                children: [
                  Icon(Icons.medical_services_outlined, color: c.teal, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mi logopeda', style: TextStyle(color: c.textMid, fontSize: 11)),
                        Text(
                          user.logopedaName ?? 'Vinculado',
                          style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
