import 'package:flutter/material.dart';
import '../../models/app_settings.dart';
import '../../models/app_user.dart';
import '../../theme/app_theme.dart';
import '../../widgets/main_app_bar.dart';
import '../../widgets/voz_menu_card.dart';
import 'ajustes_funcionales_screen.dart';
import 'colaboradores_screen.dart';
import 'perfil_screen.dart';
import 'privacidad_screen.dart';
import 'sesion_screen.dart';

/// Pantalla principal de "Ajustes": un menú con los distintos apartados,
/// cada uno en su propia pantalla. "Clonar mi voz" va destacado en un
/// color propio (dorado) mientras el paciente no tenga voz clonada, por
/// ser el paso fundacional sin el cual Texto y Frases no pueden sonar
/// con su voz.
class AjustesHomeScreen extends StatelessWidget {
  final AppSettings settings;
  final AppUser user;
  final ValueChanged<AppSettings> onSettingsChanged;
  final VoidCallback onCloneVoice;
  final VoidCallback onGoToClases;
  final VoidCallback onLogout;
  final ValueChanged<AppUser>? onUserChanged;

  const AjustesHomeScreen({
    super.key,
    required this.settings,
    required this.user,
    required this.onSettingsChanged,
    required this.onCloneVoice,
    required this.onGoToClases,
    required this.onLogout,
    this.onUserChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = AdaptiveColors.of(context);

    // Accesos directos "Mi voz"/"Clases" de la AppBar: las pantallas
    // internas de Ajustes están apiladas con Navigator.push, así que
    // primero se cierra esa pantalla y luego se ejecuta la acción.
    void goToVozDesdeSub() {
      Navigator.of(context).pop();
      onCloneVoice();
    }

    void goToClasesDesdeSub() {
      Navigator.of(context).pop();
      onGoToClases();
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: MainAppBar(
        title: 'Ajustes',
        vozPendiente: !user.hasVoice,
        onVozTap: onCloneVoice,
        onClasesTap: onGoToClases,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          // ── Mi voz (destacada) ───────────────────────────────────
          _VoiceTile(user: user, onTap: onCloneVoice),
          const SizedBox(height: 22),

          // ── Resto de apartados ───────────────────────────────────
          VozMenuCard(
            icon: Icons.settings_rounded,
            title: 'Ajustes',
            subtitle: 'Idioma, voz y accesibilidad',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AjustesFuncionalesScreen(
                  settings: settings,
                  onSettingsChanged: onSettingsChanged,
                  hasVoice: user.hasVoice,
                  onGoToVoz: goToVozDesdeSub,
                  onGoToClases: goToClasesDesdeSub,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          VozMenuCard(
            icon: Icons.person_rounded,
            title: 'Perfil',
            subtitle: 'Datos personales',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PerfilScreen(
                  user: user,
                  onGoToVoz: goToVozDesdeSub,
                  onGoToClases: goToClasesDesdeSub,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          VozMenuCard(
            icon: Icons.people_alt_rounded,
            title: 'Sesión',
            subtitle: 'Logopeda vinculado y cuenta',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SesionScreen(
                  user: user,
                  onLogout: onLogout,
                  onUserChanged: onUserChanged,
                  onGoToVoz: goToVozDesdeSub,
                  onGoToClases: goToClasesDesdeSub,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          VozMenuCard(
            icon: Icons.info_outline_rounded,
            title: 'Colaboradores',
            subtitle: 'Conoce el proyecto VOZ',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ColaboradoresScreen(
                  hasVoice: user.hasVoice,
                  onGoToVoz: goToVozDesdeSub,
                  onGoToClases: goToClasesDesdeSub,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          VozPrivacyCard(
            onMoreInfo: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PrivacidadScreen(
                  hasVoice: user.hasVoice,
                  onGoToVoz: goToVozDesdeSub,
                  onGoToClases: goToClasesDesdeSub,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tile destacada de "Mi voz" ────────────────────────────────────────
class _VoiceTile extends StatelessWidget {
  final AppUser user;
  final VoidCallback onTap;
  const _VoiceTile({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AdaptiveColors.of(context);
    // Destacada en dorado mientras no haya voz clonada (es la acción
    // pendiente más importante de la app); una vez clonada pasa a un
    // tono neutro de estado, ya sin urgencia visual.
    final highlight = !user.hasVoice;
    final color = highlight ? c.gold : c.teal;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: highlight ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: highlight ? 0.55 : 0.35),
            width: highlight ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(
                user.hasVoice ? Icons.graphic_eq_rounded : Icons.mic_none_rounded,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.hasVoice ? 'Voz clonada activa' : 'Clonar mi voz',
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    user.hasVoice
                        ? 'Toca para gestionar tu voz'
                        : 'Sube un audio para que la app hable con tu voz',
                    style: TextStyle(color: c.textMid, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color.withValues(alpha: 0.8)),
          ],
        ),
      ),
    );
  }
}
