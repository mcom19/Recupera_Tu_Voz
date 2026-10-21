import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../models/app_user.dart';
import '../../services/api_service.dart';
import '../../services/roles_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/main_app_bar.dart';

class LogopedaResumenScreen extends StatefulWidget {
  final AppUser user;
  const LogopedaResumenScreen({super.key, required this.user});

  @override
  State<LogopedaResumenScreen> createState() => _LogopedaResumenScreenState();
}

class _FichasStats {
  final int totalFichas;
  final int totalAsignaciones;
  final int totalCompletadas;
  final double tasaCompletado;
  final double? scoreMedioGlobal;
  final Map<String, dynamic> fichasPorNivel;
  const _FichasStats({
    required this.totalFichas,
    required this.totalAsignaciones,
    required this.totalCompletadas,
    required this.tasaCompletado,
    required this.scoreMedioGlobal,
    required this.fichasPorNivel,
  });
  factory _FichasStats.fromJson(Map<String, dynamic> j) => _FichasStats(
    totalFichas: j['total_fichas'] as int,
    totalAsignaciones: j['total_asignaciones'] as int,
    totalCompletadas: j['total_completadas'] as int,
    tasaCompletado: (j['tasa_completado'] as num).toDouble(),
    scoreMedioGlobal: (j['score_medio_global'] as num?)?.toDouble(),
    fichasPorNivel: j['fichas_por_nivel'] as Map<String, dynamic>,
  );
}

class _LogopedaResumenScreenState extends State<LogopedaResumenScreen> {
  AdaptiveColors get c => AdaptiveColors.of(context);

  List<PacienteInfo> _pacientes = [];
  _FichasStats? _fichasStats;
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
      final headers = {
        'Authorization': 'Bearer ${widget.user.token}',
        'Content-Type': 'application/json',
        ...kNgrokHeaders,
      };
      final results = await Future.wait([
        RolesService(widget.user.token).getMisPacientes(),
        http.get(Uri.parse('$kServerUrl/fichas/stats'), headers: headers)
            .timeout(const Duration(seconds: 10)),
      ]);

      final pacientes = results[0] as List<PacienteInfo>;
      final statsRes  = results[1] as http.Response;
      _FichasStats? stats;
      if (statsRes.statusCode == 200) {
        stats = _FichasStats.fromJson(jsonDecode(statsRes.body) as Map<String, dynamic>);
      }

      if (mounted) {
        setState(() {
        _pacientes = pacientes;
        _fichasStats = stats;
        _loading = false;
      });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: c.bg,
      appBar: MainAppBar(
        title: 'Resumen',
        showVozAction: false,
        extraActions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
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
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    if (_pacientes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_outlined, size: 64, color: c.textDim),
            const SizedBox(height: 16),
            Text('Sin datos todavía',
                style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Aquí verás el progreso de tus pacientes.',
                style: TextStyle(color: c.textDim, fontSize: 14)),
          ],
        ),
      );
    }

    final total      = _pacientes.length;
    final conVoz     = _pacientes.where((p) => p.hasVoice).length;
    final mediaRacha = _pacientes.isEmpty ? 0.0
        : _pacientes.map((p) => p.streakDays).reduce((a, b) => a + b) / total;
    final mediaLevel = _pacientes.isEmpty ? 0.0
        : _pacientes.map((p) => p.currentLevel).reduce((a, b) => a + b) / total;
    final sinTipoVoz = _pacientes.where((p) => p.voiceType == null).length;
    final fs         = _fichasStats;

    return RefreshIndicator(
      onRefresh: _load,
      color: c.accent,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // Fila 1 pacientes
          Row(children: [
            Expanded(child: _StatCard(icon: Icons.people_rounded, label: 'Pacientes', value: '$total', color: c.accent)),
            const SizedBox(width: 10),
            Expanded(child: _StatCard(icon: Icons.graphic_eq_rounded, label: 'Con voz clonada', value: '$conVoz / $total', color: c.teal)),
          ]),
          const SizedBox(height: 10),
          // Fila 2 pacientes
          Row(children: [
            Expanded(child: _StatCard(icon: Icons.local_fire_department_rounded, label: 'Racha media', value: '${mediaRacha.toStringAsFixed(1)}d', color: c.gold)),
            const SizedBox(width: 10),
            Expanded(child: _StatCard(icon: Icons.bar_chart_rounded, label: 'Nivel medio', value: mediaLevel.toStringAsFixed(1), color: c.purple)),
          ]),

          if (fs != null) ...[
            const SizedBox(height: 16),
            Text('Fichas de trabajo',
                style: TextStyle(color: c.textMid, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
            const SizedBox(height: 10),
            // Fila 1 fichas
            Row(children: [
              Expanded(child: _StatCard(icon: Icons.assignment_rounded, label: 'Fichas creadas', value: '${fs.totalFichas}', color: c.accent)),
              const SizedBox(width: 10),
              Expanded(child: _StatCard(icon: Icons.check_circle_rounded, label: 'Completadas', value: '${fs.totalCompletadas} / ${fs.totalAsignaciones}', color: c.teal)),
            ]),
            const SizedBox(height: 10),
            // Fila 2 fichas
            Row(children: [
              Expanded(child: _StatCard(icon: Icons.percent_rounded, label: 'Tasa completado', value: '${(fs.tasaCompletado * 100).round()}%', color: c.gold)),
              const SizedBox(width: 10),
              Expanded(child: _StatCard(
                icon: Icons.emoji_events_rounded,
                label: 'Score medio',
                value: fs.scoreMedioGlobal != null ? '${(fs.scoreMedioGlobal! * 100).round()}%' : '—',
                color: c.purple,
              )),
            ]),

            if (fs.fichasPorNivel.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Progreso por nivel',
                  style: TextStyle(color: c.textMid, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
              const SizedBox(height: 8),
              ...fs.fichasPorNivel.entries.map((e) {
                final nivel = e.key;
                final data  = e.value as Map<String, dynamic>;
                final comp  = data['completadas'] as int;
                final tot   = data['total'] as int;
                final score = (data['score_medio'] as num?)?.toDouble();
                final pct   = tot > 0 ? comp / tot : 0.0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.border),
                  ),
                  child: Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: c.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(child: Text('N$nivel',
                          style: TextStyle(color: c.accent, fontSize: 12, fontWeight: FontWeight.w800))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Nivel $nivel',
                          style: TextStyle(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 5,
                          backgroundColor: c.border,
                          valueColor: AlwaysStoppedAnimation(c.teal),
                        ),
                      ),
                    ])),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('$comp/$tot', style: TextStyle(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                      if (score != null)
                        Text('${(score * 100).round()}%', style: TextStyle(color: c.textDim, fontSize: 11)),
                    ]),
                  ]),
                );
              }),
            ],
          ],

          if (sinTipoVoz > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.gold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.gold.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                Icon(Icons.warning_amber_rounded, color: c.gold, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$sinTipoVoz paciente${sinTipoVoz != 1 ? 's' : ''} sin tipo de voz asignado.',
                    style: TextStyle(color: c.gold, fontSize: 13),
                  ),
                ),
              ]),
            ),
          ],

          const SizedBox(height: 20),
          Text('Detalle por paciente',
              style: TextStyle(color: c.textMid, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
          const SizedBox(height: 10),
          ..._pacientes.map((p) => _PacienteRow(p: p)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = AdaptiveColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800),
              overflow: TextOverflow.ellipsis),
          Text(label,
              style: TextStyle(color: c.textDim, fontSize: 11),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _PacienteRow extends StatelessWidget {
  final PacienteInfo p;
  const _PacienteRow({required this.p});

  @override
  Widget build(BuildContext context) {
    final c = AdaptiveColors.of(context);
    final inicial = p.name.isNotEmpty ? p.name[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 18,
          backgroundImage: p.picture != null ? NetworkImage(p.picture!) : null,
          backgroundColor: c.accent.withValues(alpha: 0.15),
          child: p.picture == null
              ? Text(inicial, style: TextStyle(color: c.accent, fontSize: 14, fontWeight: FontWeight.w700))
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name.isNotEmpty ? p.name : p.email,
                style: TextStyle(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
            if (p.voiceType != null)
              Text(
                p.voiceType == 'esofagico' ? 'Esofágica' : 'Electrolaringe',
                style: TextStyle(color: c.textDim, fontSize: 11),
              ),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          _Mini('Nv. ${p.currentLevel}', c.accent),
          const SizedBox(height: 3),
          _Mini('${p.streakDays}d 🔥', c.gold),
          if (p.hasVoice) ...[
            const SizedBox(height: 3),
            _Mini('Voz ✓', c.teal),
          ],
        ]),
      ]),
    );
  }
}

class _Mini extends StatelessWidget {
  final String label;
  final Color color;
  const _Mini(this.label, this.color);

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
  );
}