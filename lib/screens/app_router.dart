import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/app_settings.dart';
import '../services/roles_service.dart';
import 'onboarding/role_selection_screen.dart';
import 'onboarding/patient_code_screen.dart';
import 'panel/logopeda_shell.dart';
import '../main.dart' show AppShell;

class AppRouter extends StatefulWidget {
  final AppUser user;
  final AppSettings settings;
  final ValueChanged<AppSettings> onSettingsChanged;
  final ValueChanged<AppUser> onUserChanged;
  final VoidCallback onLogout;

  const AppRouter({
    super.key,
    required this.user,
    required this.settings,
    required this.onSettingsChanged,
    required this.onUserChanged,
    required this.onLogout,
  });

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  late AppUser _user;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _fetchRole();
  }

  @override
  void didUpdateWidget(AppRouter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.logopedaId != widget.user.logopedaId) {
      setState(() => _user = widget.user);
    }
  }

  Future<void> _fetchRole() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final roleInfo = await RolesService(_user.token).getRoleInfo();
      if (!mounted) return;
      setState(() {
        final serverRole    = roleInfo['role']     as String?;
        final serverRoleSet = roleInfo['role_set'] as bool? ?? false;
        _user = _user.copyWith(
          // El backend no tiene forma de guardar "paciente sin vincular"
          // (no hay endpoint para fijar el rol sin código), así que si ya
          // decidimos eso localmente no dejamos que un role_set=false del
          // servidor nos mande otra vez a elegir perfil.
          role:         serverRole ?? _user.role,
          roleSet:      serverRoleSet || _user.roleSet,
          logopedaId:   roleInfo['logopeda_id']  as String?,
          logopedaName: roleInfo['logopeda_name'] as String?,
        );
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'Sin conexión al servidor'; });
    }
  }

  void _onRoleSet(AppUser updated) {
    if (!mounted) return;
    widget.onUserChanged(updated);
    setState(() => _user = updated);
  }

  void _onSkipLogopeda() {
    _onRoleSet(_user.copyWith(logopedaSkipped: true));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              const Text(
                'No se pudo conectar con el servidor.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: _fetchRole, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    if (!_user.roleSet) {
      return RoleSelectionScreen(user: _user, onRoleSet: _onRoleSet);
    }

    if (_user.isLogopeda) {
      return LogopedaShell(
        user: _user,
        settings: widget.settings,
        onLogout: widget.onLogout,
      );
    }

    if (_user.isPatient &&
        (_user.logopedaId == null || _user.logopedaId!.isEmpty) &&
        !_user.logopedaSkipped) {
      return PatientCodeScreen(
        user: _user,
        onLinked: _onRoleSet,
        onSkip: _onSkipLogopeda,
      );
    }

    return AppShell(
      user: _user,
      settings: widget.settings,
      onSettingsChanged: widget.onSettingsChanged,
      onUserChanged: widget.onUserChanged,
      onLogout: widget.onLogout,
    );
  }
}