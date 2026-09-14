import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../models/app_user.dart';
import '../../services/api_service.dart';
import '../../services/roles_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/main_app_bar.dart';

// ── Modelo ficha ─────────────────────────────────────────────────

class FichaLogopeda {
  final String id;
  final String name;
  final int level;
  final List<String> words;
  final String? instructions;
  final double successThreshold;
  final DateTime createdAt;

  const FichaLogopeda({
    required this.id,
    required this.name,
    required this.level,
    required this.words,
    this.instructions,
    required this.successThreshold,
    required this.createdAt,
  });

  factory FichaLogopeda.fromJson(Map<String, dynamic> j) => FichaLogopeda(
    id:               j['id']                as String,
    name:             j['name']              as String,
    level:            j['level']             as int,
    words:            (j['words'] as List).cast<String>(),
    instructions:     j['instructions']      as String?,
    successThreshold: (j['success_threshold'] as num).toDouble(),
    createdAt:        DateTime.parse(j['created_at'] as String),
  );
}

// ── Servicio fichas ───────────────────────────────────────────────

class _FichasService {
  final String token;
  const _FichasService(this.token);

  Map<String, String> get _h => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
    ...kNgrokHeaders,
  };

  Future<List<FichaLogopeda>> getMisFichas() async {
    final r = await http
        .get(Uri.parse('$kServerUrl/fichas/mis-fichas'), headers: _h)
        .timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) throw Exception('Error: ${r.body}');
    return (jsonDecode(r.body) as List)
        .map((e) => FichaLogopeda.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<FichaLogopeda> crearFicha({
    required String name,
    required int level,
    required List<String> words,
    String? instructions,
    double successThreshold = 0.7,
  }) async {
    final r = await http
        .post(
      Uri.parse('$kServerUrl/fichas'),
      headers: _h,
      body: jsonEncode({
        'name': name,
        'level': level,
        'words': words,
        'instructions': instructions,
        'success_threshold': successThreshold,
      }),
    )
        .timeout(const Duration(seconds: 10));
    if (r.statusCode != 200 && r.statusCode != 201) {
      final err = jsonDecode(r.body);
      throw Exception(err['detail'] ?? 'Error creando ficha');
    }
    return FichaLogopeda.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<void> asignarFicha(String fichaId, String pacienteId) async {
    final r = await http
        .post(
      Uri.parse('$kServerUrl/fichas/$fichaId/asignar'),
      headers: _h,
      body: jsonEncode({'paciente_id': pacienteId}),
    )
        .timeout(const Duration(seconds: 10));
    if (r.statusCode != 200 && r.statusCode != 201) {
      final err = jsonDecode(r.body);
      throw Exception(err['detail'] ?? 'Error asignando ficha');
    }
  }

  /// Asigna la ficha a todos los pacientes del logopeda con el nivel indicado.
  /// Devuelve cuántos pacientes recibieron la ficha (assigned_count).
  Future<int> asignarFichaPorNivel(String fichaId, int nivel) async {
    final r = await http
        .post(
      Uri.parse('$kServerUrl/fichas/$fichaId/asignar-nivel'),
      headers: _h,
      body: jsonEncode({'nivel': nivel}),
    )
        .timeout(const Duration(seconds: 10));
    if (r.statusCode != 200 && r.statusCode != 201) {
      final err = jsonDecode(r.body);
      throw Exception(err['detail'] ?? 'Error asignando ficha por nivel');
    }
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    return (data['assigned_count'] as int?) ?? 0;
  }

  Future<void> eliminarFicha(String fichaId) async {
    final r = await http
        .delete(Uri.parse('$kServerUrl/fichas/$fichaId'), headers: _h)
        .timeout(const Duration(seconds: 10));
    if (r.statusCode != 200 && r.statusCode != 204) {
      throw Exception('Error eliminando ficha');
    }
  }
}

// ── Pantalla principal ────────────────────────────────────────────

class LogopedaFichasScreen extends StatefulWidget {
  final AppUser user;
  const LogopedaFichasScreen({super.key, required this.user});

  @override
  State<LogopedaFichasScreen> createState() => _LogopedaFichasScreenState();
}

class _LogopedaFichasScreenState extends State<LogopedaFichasScreen> {
  AdaptiveColors get c => AdaptiveColors.of(context);

  late final _FichasService _svc;
  List<FichaLogopeda> _fichas = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _svc = _FichasService(widget.user.token);
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _svc.getMisFichas();
      if (mounted) setState(() { _fichas = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _nuevaFicha() async {
    final created = await showModalBottomSheet<FichaLogopeda>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _NuevaFichaSheet(svc: _svc),
    );
    if (created != null) {
      setState(() => _fichas.insert(0, created));
    }
  }

  void _asignar(FichaLogopeda ficha) async {
    List<PacienteInfo> pacientes;
    try {
      pacientes = await RolesService(widget.user.token).getMisPacientes();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando pacientes: $e'), backgroundColor: c.warn),
        );
      }
      return;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,  // BUG 4 FIX: necesario para ConstrainedBox
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AsignarSheet(
        ficha: ficha,
        pacientes: pacientes,
        svc: _svc,
      ),
    );
  }

  Future<void> _eliminar(FichaLogopeda ficha) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Eliminar ficha', style: TextStyle(color: c.textPrimary)),
        content: Text('¿Eliminar "${ficha.name}"? Esta acción no se puede deshacer.',
            style: TextStyle(color: c.textMid)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text('Cancelar', style: TextStyle(color: c.textDim))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: Text('Eliminar', style: TextStyle(color: c.warn))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.eliminarFicha(ficha.id);
      setState(() => _fichas.removeWhere((f) => f.id == ficha.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: c.warn),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: c.bg,
      appBar: MainAppBar(
        title: 'Fichas${_fichas.isNotEmpty ? ' (${_fichas.length})' : ''}',
        showVozAction: false,
        extraActions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Nueva ficha',
            onPressed: _nuevaFicha,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: c.textDim),
            const SizedBox(height: 12),
            Text('Error al cargar', style: TextStyle(color: c.textPrimary)),
            const SizedBox(height: 6),
            Text(_error!, style: TextStyle(color: c.textDim, fontSize: 12), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    if (_fichas.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.assignment_outlined, size: 64, color: c.textDim),
              const SizedBox(height: 16),
              Text('Sin fichas creadas',
                  style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('Crea fichas con palabras para asignar a tus pacientes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.textDim, fontSize: 14, height: 1.5)),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _nuevaFicha,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Crear ficha'),
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

    // Agrupar fichas por nivel para mejor UX
    final byLevel = <int, List<FichaLogopeda>>{};
    for (final f in _fichas) {
      byLevel.putIfAbsent(f.level, () => []).add(f);
    }
    final levels = byLevel.keys.toList()..sort();

    return RefreshIndicator(
      onRefresh: _load,
      color: c.accent,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final lvl in levels) ...[
            _SectionHeader('Nivel $lvl (${byLevel[lvl]!.length})', c),
            const SizedBox(height: 8),
            ...byLevel[lvl]!.map((f) => _FichaTile(
              ficha: f,
              onAsignar: () => _asignar(f),
              onEliminar: () => _eliminar(f),
            )),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

// ── Ficha tile ────────────────────────────────────────────────────

class _FichaTile extends StatelessWidget {
  final FichaLogopeda ficha;
  final VoidCallback onAsignar;
  final VoidCallback onEliminar;
  const _FichaTile({required this.ficha, required this.onAsignar, required this.onEliminar});

  @override
  Widget build(BuildContext context) {
    final c = AdaptiveColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(ficha.name,
                    style: TextStyle(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              _Chip('Nv. ${ficha.level}', c.accent),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: ficha.words.take(6).map((w) => _WordPill(w, c)).toList()
              ..addAll(ficha.words.length > 6
                  ? [_WordPill('+${ficha.words.length - 6} más', c, dim: true)]
                  : []),
          ),
          if (ficha.instructions != null && ficha.instructions!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(ficha.instructions!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: c.textDim, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onAsignar,
                  icon: const Icon(Icons.person_add_rounded, size: 16),
                  label: const Text('Asignar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.accent,
                    side: BorderSide(color: c.accent.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: c.warn, size: 20),
                onPressed: onEliminar,
                tooltip: 'Eliminar',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Sheet crear ficha ─────────────────────────────────────────────

class _NuevaFichaSheet extends StatefulWidget {
  final _FichasService svc;
  const _NuevaFichaSheet({required this.svc});

  @override
  State<_NuevaFichaSheet> createState() => _NuevaFichaSheetState();
}

class _NuevaFichaSheetState extends State<_NuevaFichaSheet> {
  AdaptiveColors get c => AdaptiveColors.of(context);

  final _nameCtrl = TextEditingController();
  final _instrCtrl = TextEditingController();
  final _wordCtrl  = TextEditingController();
  int _level = 1;
  double _threshold = 0.7;
  final List<String> _words = [];
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _instrCtrl.dispose();
    _wordCtrl.dispose();
    super.dispose();
  }

  void _cargarEjemplo() {
    setState(() {
      _nameCtrl.text = 'Vocales básicas';
      _instrCtrl.text = 'Pronuncia cada vocal claramente, con calma y buena resonancia.';
      _level = 1;
      _threshold = 0.7;
      _words
        ..clear()
        ..addAll(['A', 'E', 'I', 'O', 'U', 'AEI', 'OUA']);
    });
  }

  void _addWord() {
    final w = _wordCtrl.text.trim();
    if (w.isEmpty) return;
    setState(() { _words.add(w); _wordCtrl.clear(); });
  }

  Future<void> _crear() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'El nombre es obligatorio.');
      return;
    }
    if (_words.isEmpty) {
      setState(() => _error = 'Añade al menos una palabra.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final ficha = await widget.svc.crearFicha(
        name: _nameCtrl.text.trim(),
        level: _level,
        words: _words,
        instructions: _instrCtrl.text.trim().isEmpty ? null : _instrCtrl.text.trim(),
        successThreshold: _threshold,
      );
      if (mounted) Navigator.of(context).pop(ficha);
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // BUG 4 FIX: altura máxima + padding para el teclado
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: mq.size.height * 0.92,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, mq.viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Nueva ficha',
                      style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                  TextButton.icon(
                    onPressed: _cargarEjemplo,
                    icon: Icon(Icons.auto_awesome_rounded, size: 16, color: c.accent),
                    label: Text('Ejemplo', style: TextStyle(color: c.accent, fontSize: 13)),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _Label('Nombre', c),
              const SizedBox(height: 6),
              TextField(
                controller: _nameCtrl,
                style: TextStyle(color: c.textPrimary),
                decoration: _deco('Ej: Vocales básicas', c),
              ),
              const SizedBox(height: 16),

              _Label('Nivel', c),
              const SizedBox(height: 6),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline_rounded, color: c.textMid),
                    onPressed: _level > 1 ? () => setState(() => _level--) : null,
                  ),
                  Expanded(
                    child: Text('Nivel $_level',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    icon: Icon(Icons.add_circle_outline_rounded, color: c.accent),
                    onPressed: () => setState(() => _level++),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _Label('Palabras', c),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _wordCtrl,
                      style: TextStyle(color: c.textPrimary),
                      decoration: _deco('Añadir palabra', c),
                      onSubmitted: (_) => _addWord(),
                      textInputAction: TextInputAction.done,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _addWord,
                    style: FilledButton.styleFrom(
                      backgroundColor: c.accent,
                      foregroundColor: c.bg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    child: const Icon(Icons.add_rounded, size: 20),
                  ),
                ],
              ),
              if (_words.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _words.map((w) => Chip(
                    label: Text(w, style: TextStyle(color: c.textPrimary, fontSize: 13)),
                    backgroundColor: c.accent.withValues(alpha: 0.1),
                    side: BorderSide(color: c.accent.withValues(alpha: 0.3)),
                    deleteIcon: Icon(Icons.close, size: 14, color: c.textDim),
                    onDeleted: () => setState(() => _words.remove(w)),
                  )).toList(),
                ),
              ],
              const SizedBox(height: 16),

              _Label('Instrucciones (opcional)', c),
              const SizedBox(height: 6),
              TextField(
                controller: _instrCtrl,
                style: TextStyle(color: c.textPrimary),
                maxLines: 3,
                decoration: _deco('Indicaciones para el paciente...', c),
              ),
              const SizedBox(height: 16),

              _Label('Umbral de éxito: ${(_threshold * 100).round()}%', c),
              Slider(
                value: _threshold,
                min: 0.5, max: 1.0, divisions: 10,
                activeColor: c.accent,
                inactiveColor: c.border,
                onChanged: (v) => setState(() => _threshold = v),
              ),

              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: c.warn, fontSize: 13)),
              ],
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _crear,
                  style: FilledButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: c.bg,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: c.bg))
                      : const Text('Crear ficha', style: TextStyle(fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sheet asignar (individual + por nivel) ────────────────────────

class _AsignarSheet extends StatefulWidget {
  final FichaLogopeda ficha;
  final List<PacienteInfo> pacientes;
  final _FichasService svc;
  const _AsignarSheet({required this.ficha, required this.pacientes, required this.svc});

  @override
  State<_AsignarSheet> createState() => _AsignarSheetState();
}

enum _AsignarMode { individual, porNivel }

class _AsignarSheetState extends State<_AsignarSheet> {
  AdaptiveColors get c => AdaptiveColors.of(context);

  _AsignarMode _mode = _AsignarMode.individual;
  final Set<String> _selected = {};
  int _nivelSeleccionado = 1;
  bool _saving = false;

  // Niveles disponibles entre los pacientes del logopeda
  late final List<int> _nivelesDisponibles;

  @override
  void initState() {
    super.initState();
    final niveles = widget.pacientes.map((p) => p.currentLevel).toSet().toList()..sort();
    _nivelesDisponibles = niveles.isEmpty ? [1] : niveles;
    _nivelSeleccionado = _nivelesDisponibles.first;
  }

  Future<void> _asignarIndividual() async {
    if (_selected.isEmpty) return;
    setState(() => _saving = true);
    int ok = 0;
    for (final id in _selected) {
      try {
        await widget.svc.asignarFicha(widget.ficha.id, id);
        ok++;
      } catch (_) {}
    }
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ficha asignada a $ok paciente${ok != 1 ? 's' : ''}'),
          backgroundColor: c.teal,
        ),
      );
    }
  }

  Future<void> _asignarPorNivel() async {
    setState(() => _saving = true);
    try {
      final count = await widget.svc.asignarFichaPorNivel(
          widget.ficha.id, _nivelSeleccionado);
      if (mounted) {
        Navigator.of(context).pop();
        final msg = count > 0
            ? 'Ficha asignada a $count paciente${count != 1 ? 's' : ''} del nivel $_nivelSeleccionado'
            : 'Los pacientes del nivel $_nivelSeleccionado ya tenían esta ficha';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: c.teal),
        );
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
    final mq = MediaQuery.of(context);
    return ConstrainedBox(
      // BUG 4 FIX: evitar overflow cuando hay muchos pacientes
      constraints: BoxConstraints(maxHeight: mq.size.height * 0.85),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, mq.viewInsets.bottom + 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Asignar "${widget.ficha.name}"',
                style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),

            // Toggle individual / por nivel
            Row(
              children: [
                Expanded(child: _ModeBtn(
                  label: 'Individual',
                  icon: Icons.person_rounded,
                  selected: _mode == _AsignarMode.individual,
                  onTap: () => setState(() => _mode = _AsignarMode.individual),
                  c: c,
                )),
                const SizedBox(width: 8),
                Expanded(child: _ModeBtn(
                  label: 'Por nivel',
                  icon: Icons.bar_chart_rounded,
                  selected: _mode == _AsignarMode.porNivel,
                  onTap: () => setState(() => _mode = _AsignarMode.porNivel),
                  c: c,
                )),
              ],
            ),
            const SizedBox(height: 16),

            if (_mode == _AsignarMode.individual) ...[
              Text('Selecciona los pacientes',
                  style: TextStyle(color: c.textDim, fontSize: 13)),
              const SizedBox(height: 8),
              if (widget.pacientes.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('No tienes pacientes vinculados.',
                      style: TextStyle(color: c.textDim)),
                )
              else
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: widget.pacientes.map((p) {
                        final sel = _selected.contains(p.userId);
                        return CheckboxListTile(
                          value: sel,
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _selected.add(p.userId);
                            } else {
                              _selected.remove(p.userId);
                            }
                          }),
                          activeColor: c.accent,
                          title: Text(p.name.isNotEmpty ? p.name : p.email,
                              style: TextStyle(color: c.textPrimary, fontSize: 14)),
                          subtitle: Row(
                            children: [
                              Text(p.email, style: TextStyle(color: c.textDim, fontSize: 12)),
                              const SizedBox(width: 6),
                              _Chip('Nv. ${p.currentLevel}', c.accent),
                            ],
                          ),
                          contentPadding: EdgeInsets.zero,
                        );
                      }).toList(),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (_selected.isEmpty || _saving) ? null : _asignarIndividual,
                  style: FilledButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: c.bg,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: c.bg))
                      : Text('Asignar a ${_selected.length} paciente${_selected.length != 1 ? 's' : ''}'),
                ),
              ),
            ] else ...[
              // Modo por nivel
              Text('Elige el nivel al que quieres asignar esta ficha.\nTodos los pacientes de ese nivel la recibirán.',
                  style: TextStyle(color: c.textDim, fontSize: 13, height: 1.5)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Nivel:', style: TextStyle(color: c.textMid, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 12),
                  ..._nivelesDisponibles.map((n) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('$n'),
                      selected: _nivelSeleccionado == n,
                      onSelected: (_) => setState(() => _nivelSeleccionado = n),
                      selectedColor: c.accent.withValues(alpha: 0.2),
                      labelStyle: TextStyle(
                        color: _nivelSeleccionado == n ? c.accent : c.textMid,
                        fontWeight: FontWeight.w600,
                      ),
                      side: BorderSide(
                        color: _nivelSeleccionado == n
                            ? c.accent
                            : c.border,
                      ),
                    ),
                  )),
                ],
              ),
              const SizedBox(height: 8),
              // Mostrar cuántos pacientes hay en ese nivel
              Builder(builder: (ctx) {
                final count = widget.pacientes
                    .where((p) => p.currentLevel == _nivelSeleccionado)
                    .length;
                return Text(
                  '$count paciente${count != 1 ? 's' : ''} en el nivel $_nivelSeleccionado',
                  style: TextStyle(color: c.textDim, fontSize: 12),
                );
              }),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _asignarPorNivel,
                  icon: const Icon(Icons.group_add_rounded, size: 18),
                  label: _saving
                      ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Asignar a todos en nivel $_nivelSeleccionado'),
                  style: FilledButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: c.bg,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModeBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final AdaptiveColors c;
  const _ModeBtn({required this.label, required this.icon, required this.selected,
    required this.onTap, required this.c});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? c.accent.withValues(alpha: 0.12) : c.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? c.accent : c.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? c.accent : c.textDim),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  color: selected ? c.accent : c.textMid,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                )),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  final AdaptiveColors c;
  const _SectionHeader(this.text, this.c);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(
      text,
      style: TextStyle(
          color: c.textMid,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4),
    ),
  );
}

InputDecoration _deco(String hint, AdaptiveColors c) => InputDecoration(
  hintText: hint,
  hintStyle: TextStyle(color: c.textDim),
  filled: true,
  fillColor: c.bg,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: c.border),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: c.border),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: c.accent, width: 1.5),
  ),
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
);

Widget _Label(String text, AdaptiveColors c) => Text(
  text,
  style: TextStyle(color: c.textMid, fontSize: 12, fontWeight: FontWeight.w600),
);

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
  );
}

class _WordPill extends StatelessWidget {
  final String word;
  final AdaptiveColors c;
  final bool dim;
  const _WordPill(this.word, this.c, {this.dim = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: dim ? c.border.withValues(alpha: 0.3) : c.surface,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: c.border),
    ),
    child: Text(word,
        style: TextStyle(color: dim ? c.textDim : c.textMid, fontSize: 12)),
  );
}
