import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../services/roles_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/main_app_bar.dart';
import '../../widgets/voz_menu_card.dart';

/// Acciones de sesión: desvincular logopeda y cerrar sesión.
class SesionScreen extends StatefulWidget {
  final AppUser user;
  final VoidCallback onLogout;
  final ValueChanged<AppUser>? onUserChanged;
  final VoidCallback onGoToVoz;
  final VoidCallback onGoToClases;

  const SesionScreen({
    super.key,
    required this.user,
    required this.onLogout,
    this.onUserChanged,
    required this.onGoToVoz,
    required this.onGoToClases,
  });

  @override
  State<SesionScreen> createState() => _SesionScreenState();
}

class _SesionScreenState extends State<SesionScreen> {
  AdaptiveColors get c => AdaptiveColors.of(context);
  late AppUser _user;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
  }

  Future<void> _confirmarDesvincular() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Desvincular logopeda', style: TextStyle(color: c.textPrimary)),
        content: Text(
          '¿Seguro que quieres desvincularte de tu logopeda? '
          'Perderás acceso a las fichas asignadas.',
          style: TextStyle(color: c.textMid),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: TextStyle(color: c.textDim)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Desvincular', style: TextStyle(color: c.warn, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await RolesService(_user.token).desvincularme();
      if (!mounted) return;
      final updatedUser = _user.copyWith(logopedaId: null, logopedaName: null);
      setState(() => _user = updatedUser);
      widget.onUserChanged?.call(updatedUser);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Desvinculado correctamente'),
            backgroundColor: c.teal,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: c.warn),
        );
      }
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Cerrar sesión', style: TextStyle(color: c.textPrimary)),
        content: Text('¿Seguro que quieres cerrar sesión?', style: TextStyle(color: c.textMid)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: c.textDim)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onLogout();
            },
            child: Text('Cerrar sesión', style: TextStyle(color: c.warn)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: c.bg,
      appBar: MainAppBar(
        title: 'Sesión',
        vozPendiente: !_user.hasVoice,
        onVozTap: widget.onGoToVoz,
        onClasesTap: widget.onGoToClases,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_user.isPatient && _user.logopedaId != null && _user.logopedaId!.isNotEmpty) ...[
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
                          _user.logopedaName ?? 'Vinculado',
                          style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _confirmarDesvincular,
                    child: Text('Desvincular', style: TextStyle(color: c.warn, fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          GestureDetector(
            onTap: _confirmLogout,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: vozCardDecoration(radius: 10),
              child: Row(
                children: [
                  Icon(Icons.logout_rounded, color: c.warn, size: 18),
                  const SizedBox(width: 10),
                  Text('Cerrar sesión', style: TextStyle(color: c.warn, fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
