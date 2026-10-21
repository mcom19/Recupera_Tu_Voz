// lib/screens/panel/logopeda_shell.dart

import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/app_settings.dart';
import '../../theme/app_theme.dart';
import '../../widgets/main_app_bar.dart';
import 'logopeda_pacientes_screen.dart';
import 'logopeda_fichas_screen.dart';
import 'logopeda_videos_screen.dart';
import 'logopeda_resumen_screen.dart';

class LogopedaShell extends StatefulWidget {
  final AppUser user;
  final AppSettings settings;
  final VoidCallback onLogout;

  const LogopedaShell({
    super.key,
    required this.user,
    required this.settings,
    required this.onLogout,
  });

  @override
  State<LogopedaShell> createState() => _LogopedaShellState();
}

class _LogopedaShellState extends State<LogopedaShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final c = AdaptiveColors.of(context);

    final screens = [
      LogopedaPacientesScreen(user: widget.user),
      LogopedaFichasScreen(user: widget.user),
      LogopedaVideosScreen(user: widget.user),
      LogopedaResumenScreen(user: widget.user),
      _LogopedaPerfilScreen(user: widget.user, onLogout: widget.onLogout),
    ];

    return Scaffold(
      body: IndexedStack(index: _tab, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        indicatorColor: const Color(0xFF1CE7B2).withValues(alpha: 0.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded, color: Color(0xFF1CE7B2)),
            label: 'Pacientes',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment_rounded, color: Color(0xFF1CE7B2)),
            label: 'Fichas',
          ),
          NavigationDestination(
            icon: Icon(Icons.video_library_outlined),
            selectedIcon: Icon(Icons.video_library_rounded, color: Color(0xFF1CE7B2)),
            label: 'Vídeos',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded, color: Color(0xFF1CE7B2)),
            label: 'Resumen',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: Color(0xFF1CE7B2)),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

// ── Pestaña perfil logopeda ───────────────────────────────────────

class _LogopedaPerfilScreen extends StatelessWidget {
  final AppUser user;
  final VoidCallback onLogout;
  const _LogopedaPerfilScreen({required this.user, required this.onLogout});

  void _confirmLogout(BuildContext context) {
    final c = AdaptiveColors.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Cerrar sesión', style: TextStyle(color: c.textPrimary)),
        content: Text('¿Seguro que quieres cerrar sesión?',
            style: TextStyle(color: c.textMid)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: c.textDim)),
          ),
          TextButton(
            onPressed: () { Navigator.pop(context); onLogout(); },
            child: Text('Cerrar sesión', style: TextStyle(color: c.warn)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AdaptiveColors.of(context);
    final inicial = user.name.isNotEmpty ? user.name[0].toUpperCase() : 'L';

    return Scaffold(
      backgroundColor: c.bg,
      appBar: MainAppBar(title: 'Mi perfil', showVozAction: false),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: user.picture != null ? NetworkImage(user.picture!) : null,
                  backgroundColor: c.accent.withValues(alpha: 0.15),
                  child: user.picture == null
                      ? Text(inicial, style: TextStyle(color: c.accent, fontSize: 22, fontWeight: FontWeight.w700))
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name.isNotEmpty ? user.name : 'Sin nombre',
                          style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(user.email, style: TextStyle(color: c.textDim, fontSize: 13)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: c.teal.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('Logopeda',
                            style: TextStyle(color: c.teal, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          GestureDetector(
            onTap: () => _confirmLogout(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.warn.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.logout_rounded, color: c.warn, size: 20),
                  const SizedBox(width: 12),
                  Text('Cerrar sesión',
                      style: TextStyle(color: c.warn, fontSize: 15, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}