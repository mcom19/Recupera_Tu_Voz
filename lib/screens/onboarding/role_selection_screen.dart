// lib/screens/onboarding/role_selection_screen.dart

import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../services/roles_service.dart';
import 'patient_code_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  final AppUser user;
  final void Function(AppUser updatedUser) onRoleSet;

  const RoleSelectionScreen({
    super.key,
    required this.user,
    required this.onRoleSet,
  });

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  bool _loading = false;

  Future<void> _chooseLogopeda() async {
    setState(() => _loading = true);
    try {
      final svc  = RolesService(widget.user.token);
      final data = await svc.setLogopeda();
      final updated = widget.user.copyWith(
        role:    data['role'],
        roleSet: data['role_set'],
      );
      if (mounted) widget.onRoleSet(updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _choosePatient() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PatientCodeScreen(
        user: widget.user,
        onLinked: widget.onRoleSet,
        // "Más tarde": entra como paciente sin logopeda; podrá vincularse desde el perfil.
        onSkip: () {
          Navigator.of(context).pop();
          widget.onRoleSet(widget.user.copyWith(
            role: 'patient',
            roleSet: true,
            logopedaSkipped: true,
          ));
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                '¿Cómo vas a usar\nRecupera tu voz?',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Elige tu perfil para personalizar la app.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 48),
              _RoleCard(
                icon: Icons.medical_services_outlined,
                color: const Color(0xFF0F6E56),
                backgroundColor: const Color(0xFFE1F5EE),
                title: 'Soy logopeda',
                subtitle: 'Gestiono pacientes, fichas y seguimiento del progreso.',
                onTap: _loading ? null : _chooseLogopeda,
              ),
              const SizedBox(height: 16),
              _RoleCard(
                icon: Icons.record_voice_over_outlined,
                color: const Color(0xFF185FA5),
                backgroundColor: const Color(0xFFE6F1FB),
                title: 'Soy paciente',
                subtitle: 'Hago ejercicios de voz y sigo mi rehabilitación.',
                onTap: _loading ? null : _choosePatient,
              ),
              const SizedBox(height: 48),
              if (_loading)
                const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Esta selección no se puede cambiar después.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _RoleCard({
    required this.icon,
    required this.color,
    required this.backgroundColor,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.35), width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}