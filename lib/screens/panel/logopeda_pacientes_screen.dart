// lib/screens/panel/logopeda_pacientes_screen.dart

import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../services/roles_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/main_app_bar.dart';
import 'logopeda_codigo_screen.dart';

class LogopedaPacientesScreen extends StatefulWidget {
  final AppUser user;
  const LogopedaPacientesScreen({super.key, required this.user});

  @override
  State<LogopedaPacientesScreen> createState() => _LogopedaPacientesScreenState();
}

class _LogopedaPacientesScreenState extends State<LogopedaPacientesScreen> {
  AdaptiveColors get c => AdaptiveColors.of(context);

  List<PacienteInfo> _pacientes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await RolesService(widget.user.token).getMisPacientes();
      if (mounted) setState(() { _pacientes = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _abrirDetalle(PacienteInfo p) async {
    final updated = await Navigator.of(context).push<PacienteInfo>(
      MaterialPageRoute(
        builder: (_) => _PacienteDetalleScreen(
          paciente: p,
          token: widget.user.token,
        ),
      ),
    );
    if (!mounted) return;
    if (updated == null) {
      // Paciente desvinculado: eliminar de la lista
      setState(() => _pacientes.removeWhere((x) => x.userId == p.userId));
    } else {
      setState(() {
        final idx = _pacientes.indexWhere((x) => x.userId == updated.userId);
        if (idx != -1) _pacientes[idx] = updated;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: c.bg,
      appBar: MainAppBar(
        title: 'Mis pacientes${_pacientes.isNotEmpty ? ' (${_pacientes.length})' : ''}',
        showVozAction: false,
        extraActions: [
          IconButton(
            tooltip: 'Código de vinculación',
            icon: const Icon(Icons.link_rounded),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => LogopedaCodigoScreen(user: widget.user),
            )),
          ),
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 48, color: c.textDim),
              const SizedBox(height: 12),
              Text('Error al cargar', style: TextStyle(color: c.textPrimary, fontSize: 16)),
              const SizedBox(height: 6),
              Text(_error!, textAlign: TextAlign.center,
                  style: TextStyle(color: c.textDim, fontSize: 12)),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    if (_pacientes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people_outline_rounded, size: 64, color: c.textDim),
              const SizedBox(height: 16),
              Text('Sin pacientes vinculados',
                  style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('Genera un código y compártelo con tus pacientes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.textDim, fontSize: 14, height: 1.5)),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => LogopedaCodigoScreen(user: widget.user),
                )),
                icon: const Icon(Icons.link_rounded),
                label: const Text('Generar código'),
                style: FilledButton.styleFrom(
                  backgroundColor: c.accent,
                  foregroundColor: c.bg,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: c.accent,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _pacientes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _PacienteTile(
          paciente: _pacientes[i],
          onTap: () => _abrirDetalle(_pacientes[i]),
        ),
      ),
    );
  }
}

// ── Tile ─────────────────────────────────────────────────────────

class _PacienteTile extends StatelessWidget {
  final PacienteInfo paciente;
  final VoidCallback onTap;
  const _PacienteTile({required this.paciente, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AdaptiveColors.of(context);
    final inicial = paciente.name.isNotEmpty ? paciente.name[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            _Avatar(picture: paciente.picture, inicial: inicial, accent: c.accent),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    paciente.name.isNotEmpty ? paciente.name : 'Sin nombre',
                    style: TextStyle(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(paciente.email,
                      style: TextStyle(color: c.textDim, fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _Badge(icon: Icons.bar_chart_rounded, label: 'Nv. ${paciente.currentLevel}', color: c.accent),
                      _Badge(icon: Icons.local_fire_department_rounded, label: '${paciente.streakDays}d', color: c.gold),
                      if (paciente.hasVoice)
                        _Badge(icon: Icons.graphic_eq_rounded, label: 'Voz', color: c.teal),
                      if (paciente.voiceType != null)
                        _Badge(
                          icon: Icons.mic_rounded,
                          label: paciente.voiceType == 'esofagico' ? 'Esofágica' : 'Electrolaringe',
                          color: c.purple,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: c.textDim, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Pantalla detalle / edición ────────────────────────────────────

class _PacienteDetalleScreen extends StatefulWidget {
  final PacienteInfo paciente;
  final String token;
  const _PacienteDetalleScreen({required this.paciente, required this.token});

  @override
  State<_PacienteDetalleScreen> createState() => _PacienteDetalleScreenState();
}

class _PacienteDetalleScreenState extends State<_PacienteDetalleScreen> {
  AdaptiveColors get c => AdaptiveColors.of(context);

  late PacienteInfo _p;
  bool _saving = false;

  // Estado editable local
  String? _voiceType;
  late int _level;

  @override
  void initState() {
    super.initState();
    _p = widget.paciente;
    _voiceType = _p.voiceType;
    _level = _p.currentLevel;
  }

  bool get _dirty => _voiceType != _p.voiceType || _level != _p.currentLevel;

  Future<void> _guardar() async {
    if (!_dirty || _saving) return;
    setState(() => _saving = true);
    try {
      final updated = await RolesService(widget.token).patchPaciente(
        _p.userId,
        voiceType: _voiceType,
        currentLevel: _level,
      );
      if (mounted) {
        setState(() { _p = updated; _saving = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Cambios guardados'),
            backgroundColor: c.teal,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop(updated);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: c.warn),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inicial = _p.name.isNotEmpty ? _p.name[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: c.bg,
      appBar: MainAppBar(
        title: _p.name.isNotEmpty ? _p.name : 'Paciente',
        showVozAction: false,
        extraActions: [
          if (_dirty)
            TextButton(
              onPressed: _saving ? null : _guardar,
              child: _saving
                  ? SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
              )
                  : Text('Guardar', style: TextStyle(color: c.accent, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [

          // ── Cabecera ─────────────────────────────────────────
          Row(
            children: [
              _Avatar(picture: _p.picture, inicial: inicial, accent: c.accent, radius: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_p.name.isNotEmpty ? _p.name : 'Sin nombre',
                        style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(_p.email, style: TextStyle(color: c.textDim, fontSize: 13)),
                    const SizedBox(height: 6),
                    Text(
                      'Vinculado el ${_formatDate(_p.joinedAt)}',
                      style: TextStyle(color: c.textDim, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Stats rápidas ────────────────────────────────────
          Row(
            children: [
              _StatCard(label: 'Nivel', value: '${_p.currentLevel}', icon: Icons.bar_chart_rounded, color: c.accent),
              const SizedBox(width: 10),
              _StatCard(label: 'Racha', value: '${_p.streakDays}d', icon: Icons.local_fire_department_rounded, color: c.gold),
              const SizedBox(width: 10),
              _StatCard(
                label: 'Voz',
                value: _p.hasVoice ? 'Sí' : 'No',
                icon: Icons.graphic_eq_rounded,
                color: _p.hasVoice ? c.teal : c.textDim,
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── Tipo de voz ──────────────────────────────────────
          _SectionTitle('Tipo de voz', c),
          const SizedBox(height: 10),
          _VoiceTypeSelector(
            selected: _voiceType,
            onChanged: (v) => setState(() => _voiceType = v),
          ),
          const SizedBox(height: 24),

          // ── Nivel ────────────────────────────────────────────
          _SectionTitle('Nivel de trabajo', c),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.remove_circle_outline_rounded, color: c.textMid),
                  onPressed: _level > 1 ? () => setState(() => _level--) : null,
                ),
                Expanded(
                  child: Text(
                    'Nivel $_level',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add_circle_outline_rounded, color: c.accent),
                  onPressed: () => setState(() => _level++),
                ),
              ],
            ),
          ),

          if (_dirty) ...[
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _saving ? null : _guardar,
              style: FilledButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: c.bg,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? SizedBox(
                height: 20, width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: c.bg),
              )
                  : const Text('Guardar cambios', style: TextStyle(fontSize: 15)),
            ),
          ],

          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _saving ? null : _confirmarDesvincular,
            icon: Icon(Icons.link_off_rounded, color: c.warn, size: 18),
            label: Text('Desvincular paciente', style: TextStyle(color: c.warn)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: c.warn.withValues(alpha: 0.5)),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarDesvincular() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Desvincular paciente', style: TextStyle(color: c.textPrimary)),
        content: Text(
          '¿Seguro que quieres desvincular a ${_p.name.isNotEmpty ? _p.name : "este paciente"}? '
              'Dejará de aparecer en tu lista de pacientes.',
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
    setState(() => _saving = true);
    try {
      await RolesService(widget.token).desvincularPaciente(_p.userId);
      if (mounted) Navigator.of(context).pop(null); // null = eliminado de la lista
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: c.warn),
        );
      }
    }
  }

  String _formatDate(DateTime dt) {
    final l = dt.toLocal();
    return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}/${l.year}';
  }
}

// ── Selector tipo de voz ──────────────────────────────────────────

class _VoiceTypeSelector extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onChanged;
  const _VoiceTypeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = AdaptiveColors.of(context);
    const opciones = [
      (value: 'esofagico',     label: 'Esofágica',     icon: Icons.air_rounded),
      (value: 'electrolaringe', label: 'Electrolaringe', icon: Icons.settings_input_component_rounded),
    ];

    return Row(
      children: [
        // Opción "sin tipo"
        Expanded(
          child: _VoiceTypeChip(
            label: 'Sin definir',
            icon: Icons.help_outline_rounded,
            selected: selected == null,
            color: c.textDim,
            onTap: () => onChanged(null),
          ),
        ),
        const SizedBox(width: 8),
        ...opciones.map((o) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: opciones.indexOf(o) == 0 ? 0 : 8),
            child: _VoiceTypeChip(
              label: o.label,
              icon: o.icon,
              selected: selected == o.value,
              color: c.purple,
              onTap: () => onChanged(o.value),
            ),
          ),
        )),
      ],
    );
  }
}

class _VoiceTypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _VoiceTypeChip({
    required this.label, required this.icon,
    required this.selected, required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AdaptiveColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : c.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? color : c.textDim, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? color : c.textDim,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets compartidos ───────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String? picture;
  final String inicial;
  final Color accent;
  final double radius;
  const _Avatar({this.picture, required this.inicial, required this.accent, this.radius = 24});

  @override
  Widget build(BuildContext context) {
    if (picture != null) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(picture!),
        backgroundColor: accent.withValues(alpha: 0.1),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: accent.withValues(alpha: 0.15),
      child: Text(inicial,
          style: TextStyle(color: accent, fontSize: radius * 0.75, fontWeight: FontWeight.w700)),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Badge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = AdaptiveColors.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: c.textDim, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

Widget _SectionTitle(String text, AdaptiveColors c) => Text(
  text,
  style: TextStyle(color: c.textMid, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5),
);