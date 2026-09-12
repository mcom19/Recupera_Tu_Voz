import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../models/app_user.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../services/roles_service.dart';
import '../widgets/shared_widgets.dart';

class ProfileScreen extends StatefulWidget {
  final AppSettings settings;
  final AppUser user;
  final ValueChanged<AppSettings> onSettingsChanged;
  final VoidCallback onCloneVoice;
  final VoidCallback onLogout;
  final ValueChanged<AppUser>? onUserChanged;

  const ProfileScreen({
    super.key,
    required this.settings,
    required this.user,
    required this.onSettingsChanged,
    required this.onCloneVoice,
    required this.onLogout,
    this.onUserChanged,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  AdaptiveColors get c => AdaptiveColors.of(context);

  late AppSettings _settings;
  final SettingsService _svc = SettingsService();

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  @override
  void didUpdateWidget(ProfileScreen old) {
    super.didUpdateWidget(old);
    if (old.settings != widget.settings) setState(() => _settings = widget.settings);
  }

  void _update(AppSettings s) {
    setState(() => _settings = s);
    _svc.saveSettings(s);
    widget.onSettingsChanged(s);
  }

  void _showLanguageDialog() {
    const idiomas = ['Español', 'English', 'Français', 'Deutsch', 'Italiano'];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Idioma',
            style: TextStyle(color: c.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: idiomas
              .map((lang) => RadioListTile<String>(
            value: lang,
            groupValue: _settings.idioma,
            activeColor: c.accent,
            title: Text(lang,
                style: TextStyle(
                    color: c.textPrimary, fontSize: 14)),
            onChanged: (v) {
              _update(_settings.copyWith(idioma: v));
              Navigator.pop(context);
            },
          ))
              .toList(),
        ),
      ),
    );
  }

  Future<void> _confirmarDesvincular() async {
    final c = AdaptiveColors.of(context);
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
      await RolesService(widget.user.token).desvincularme();
      if (!mounted) return;
      final updatedUser = widget.user.copyWith(logopedaId: null, logopedaName: null);
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
        title: Text('Cerrar sesión',
            style: TextStyle(color: c.textPrimary)),
        content: Text('¿Seguro que quieres cerrar sesión?',
            style: TextStyle(color: c.textMid)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar',
                  style: TextStyle(color: c.textDim))),
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onLogout();
              },
              child: Text('Cerrar sesión',
                  style: TextStyle(color: c.warn))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          // ── Cabecera usuario ──────────────────────────────────
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: c.accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person_rounded,
                      color: c.accent, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.user.name.isEmpty ? 'Sin nombre' : widget.user.name,
                        style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(widget.user.email,
                          style: TextStyle(
                              color: c.textMid, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Mi voz ───────────────────────────────────────────
          const SectionLabel('Mi voz'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: widget.onCloneVoice,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.user.hasVoice
                    ? c.teal.withValues(alpha: 0.08)
                    : c.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: widget.user.hasVoice
                      ? c.teal.withValues(alpha: 0.35)
                      : c.accent.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.user.hasVoice
                        ? Icons.graphic_eq_rounded
                        : Icons.mic_none_rounded,
                    color: widget.user.hasVoice
                        ? c.teal
                        : c.accent,
                    size: 26,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.user.hasVoice
                              ? 'Voz clonada activa'
                              : 'Clonar mi voz',
                          style: TextStyle(
                            color: widget.user.hasVoice
                                ? c.teal
                                : c.accent,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.user.hasVoice
                              ? 'Toca para gestionar tu voz'
                              : 'Sube un audio para que la app hable con tu voz',
                          style: TextStyle(
                              color: c.textMid, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      color: c.textDim, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Ajustes ───────────────────────────────────────────
          const SectionLabel('Ajustes'),
          const SizedBox(height: 8),
          // ── Toggle tema ───────────────────────────────────────
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  _settings.temaOscuro ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  size: 18,
                  color: _settings.temaOscuro ? c.textMid : c.gold,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _settings.temaOscuro ? 'Tema oscuro' : 'Tema claro',
                    style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
                Switch(
                  value: !_settings.temaOscuro,
                  onChanged: (claro) => _update(_settings.copyWith(temaOscuro: !claro)),
                ),
              ],
            ),
          ),
          _Tile(
            label: 'Idioma',
            value: _settings.idioma,
            onTap: _showLanguageDialog,
          ),
          const SizedBox(height: 6),
          _SliderTile(
            label: 'Velocidad de voz',
            value: _settings.velocidad,
            min: 0.1, max: 1.0,
            onChanged: (v) => _update(_settings.copyWith(velocidad: v)),
          ),
          const SizedBox(height: 6),
          _SliderTile(
            label: 'Volumen',
            value: _settings.volumen,
            min: 0.1, max: 1.0,
            onChanged: (v) => _update(_settings.copyWith(volumen: v)),
          ),
          const SizedBox(height: 20),

          // ── Sesión ────────────────────────────────────────────
          const SectionLabel('Sesión'),
          const SizedBox(height: 8),
          // ── Logopeda vinculado ───────────────────────────────
          if (widget.user.isPatient && widget.user.logopedaId != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.border),
              ),
              child: Row(children: [
                Icon(Icons.medical_services_outlined, color: c.teal, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Mi logopeda', style: TextStyle(color: c.textMid, fontSize: 11)),
                  Text(widget.user.logopedaName ?? 'Vinculado', style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                ])),
                TextButton(
                  onPressed: _confirmarDesvincular,
                  child: Text('Desvincular', style: TextStyle(color: c.warn, fontSize: 12)),
                ),
              ]),
            ),
            const SizedBox(height: 8),
          ],

          GestureDetector(
            onTap: _confirmLogout,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.logout_rounded, color: c.warn, size: 18),
                  const SizedBox(width: 10),
                  Text('Cerrar sesión',
                      style: TextStyle(color: c.warn, fontSize: 14)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Widgets internos ──────────────────────────────────────────────
class _Tile extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback? onTap;
  const _Tile({required this.label, this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AdaptiveColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
            color: c.surface, borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(
                        color: c.textPrimary, fontSize: 14,
                        fontWeight: FontWeight.w500)),
                    if (value != null)
                      Text(value!, style: TextStyle(
                          color: c.textMid, fontSize: 12)),
                  ]),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right, color: c.textDim, size: 18),
          ],
        ),
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  final String label;
  final double value, min, max;
  final ValueChanged<double> onChanged;
  const _SliderTile({required this.label, required this.value,
    required this.min, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = AdaptiveColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      decoration: BoxDecoration(
          color: c.surface, borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(
            color: c.textPrimary, fontSize: 14,
            fontWeight: FontWeight.w500)),
        Slider(
          value: value, min: min, max: max,
          activeColor: c.accent,
          inactiveColor: c.border,
          onChanged: onChanged,
        ),
      ]),
    );
  }
}