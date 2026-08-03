import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

// ── Modelos ───────────────────────────────────────────────────────

class PacienteInfo {
  final String userId;
  final String name;
  final String email;
  final String? picture;
  final String? voiceType;
  final int currentLevel;
  final int streakDays;
  final bool hasVoice;
  final DateTime joinedAt;

  const PacienteInfo({
    required this.userId,
    required this.name,
    required this.email,
    this.picture,
    this.voiceType,
    required this.currentLevel,
    required this.streakDays,
    required this.hasVoice,
    required this.joinedAt,
  });

  factory PacienteInfo.fromJson(Map<String, dynamic> j) => PacienteInfo(
    userId:       j['user_id']       as String,
    name:         j['name']          as String,
    email:        j['email']         as String,
    picture:      j['picture']       as String?,
    voiceType:    j['voice_type']    as String?,
    currentLevel: j['current_level'] as int,
    streakDays:   j['streak_days']   as int,
    hasVoice:     j['has_voice']     as bool,
    joinedAt:     DateTime.parse(j['joined_at'] as String),
  );

  PacienteInfo copyWith({String? voiceType, int? currentLevel, int? streakDays}) =>
      PacienteInfo(
        userId:       userId,
        name:         name,
        email:        email,
        picture:      picture,
        voiceType:    voiceType ?? this.voiceType,
        currentLevel: currentLevel ?? this.currentLevel,
        streakDays:   streakDays ?? this.streakDays,
        hasVoice:     hasVoice,
        joinedAt:     joinedAt,
      );
}

class FichaAsignada {
  final String fichaId;
  final String name;
  final int level;
  final List<String> words;
  final String? instructions;
  final double successThreshold;
  final DateTime assignedAt;
  final DateTime? completedAt;
  final double? bestScore;

  const FichaAsignada({
    required this.fichaId,
    required this.name,
    required this.level,
    required this.words,
    this.instructions,
    required this.successThreshold,
    required this.assignedAt,
    this.completedAt,
    this.bestScore,
  });

  factory FichaAsignada.fromJson(Map<String, dynamic> j) => FichaAsignada(
    fichaId:          j['ficha_id']          as String,
    name:             j['name']              as String,
    level:            j['level']             as int,
    words:            (j['words'] as List).cast<String>(),
    instructions:     j['instructions']      as String?,
    successThreshold: (j['success_threshold'] as num).toDouble(),
    assignedAt:       DateTime.parse(j['assigned_at'] as String),
    completedAt:      j['completed_at'] != null
        ? DateTime.parse(j['completed_at'] as String)
        : null,
    bestScore: (j['best_score'] as num?)?.toDouble(),
  );

  bool get completada => completedAt != null && (bestScore == null || bestScore! >= successThreshold);

  FichaAsignada copyWith({DateTime? completedAt, double? bestScore}) => FichaAsignada(
    fichaId:          fichaId,
    name:             name,
    level:            level,
    words:            words,
    instructions:     instructions,
    successThreshold: successThreshold,
    assignedAt:       assignedAt,
    completedAt:      completedAt ?? this.completedAt,
    bestScore:        bestScore ?? this.bestScore,
  );
}

// ── Servicio ──────────────────────────────────────────────────────

class RolesService {
  final String token;
  const RolesService(this.token);

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
    ...kNgrokHeaders,
  };

  Future<Map<String, dynamic>> getRoleInfo() async {
    final r = await http
        .get(Uri.parse('$kServerUrl/roles/me'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) throw Exception('Error obteniendo rol: ${r.body}');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> setLogopeda() async {
    final r = await http
        .post(Uri.parse('$kServerUrl/roles/set-logopeda'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) throw Exception('Error: ${r.body}');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> generarCodigo() async {
    final r = await http
        .post(Uri.parse('$kServerUrl/roles/generar-codigo'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) throw Exception('Error generando código: ${r.body}');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> getMiCodigo() async {
    final r = await http
        .get(Uri.parse('$kServerUrl/roles/mi-codigo'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (r.statusCode == 200) {
      final body = jsonDecode(r.body);
      if (body == null) return null;
      return body as Map<String, dynamic>;
    }
    return null;
  }

  Future<Map<String, dynamic>> vincularPaciente(String codigo) async {
    final r = await http
        .post(
      Uri.parse('$kServerUrl/roles/vincular-paciente'),
      headers: _headers,
      body: jsonEncode({'codigo': codigo}),
    )
        .timeout(const Duration(seconds: 10));
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    final err = jsonDecode(r.body);
    throw Exception(err['detail'] ?? 'Código inválido');
  }

  Future<List<PacienteInfo>> getMisPacientes() async {
    final r = await http
        .get(Uri.parse('$kServerUrl/roles/mis-pacientes'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) throw Exception('Error cargando pacientes: ${r.body}');
    final list = jsonDecode(r.body) as List<dynamic>;
    return list.map((e) => PacienteInfo.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PacienteInfo> patchPaciente(
      String userId, {
        String? voiceType,
        int? currentLevel,
        int? streakDays,
      }) async {
    final body = <String, dynamic>{};
    if (voiceType != null) body['voice_type'] = voiceType;
    if (currentLevel != null) body['current_level'] = currentLevel;
    if (streakDays != null) body['streak_days'] = streakDays;

    final r = await http
        .patch(
      Uri.parse('$kServerUrl/roles/paciente/$userId'),
      headers: _headers,
      body: jsonEncode(body),
    )
        .timeout(const Duration(seconds: 10));

    if (r.statusCode != 200) {
      final err = jsonDecode(r.body);
      throw Exception(err['detail'] ?? 'Error actualizando paciente');
    }
    return PacienteInfo.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<List<FichaAsignada>> getMisFichas() async {
    final r = await http
        .get(Uri.parse('$kServerUrl/roles/mis-fichas'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) throw Exception('Error cargando fichas: ${r.body}');
    final list = jsonDecode(r.body) as List<dynamic>;
    return list.map((e) => FichaAsignada.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// El paciente marca una ficha como completada y envía su mejor score.
  /// Devuelve los datos actualizados (completed_at, best_score).
  Future<Map<String, dynamic>> completarFicha(
      String fichaId, {
        double? bestScore,
      }) async {
    final r = await http
        .patch(
      Uri.parse('$kServerUrl/fichas/$fichaId/completar'),
      headers: _headers,
      body: jsonEncode({'best_score': bestScore}),
    )
        .timeout(const Duration(seconds: 10));

    if (r.statusCode != 200) {
      final err = jsonDecode(r.body);
      throw Exception(err['detail'] ?? 'Error al completar la ficha');
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// El logopeda desvincula a un paciente de su lista.
  Future<void> desvincularPaciente(String userId) async {
    final r = await http
        .delete(Uri.parse('$kServerUrl/roles/desvincular-paciente/$userId'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) {
      final err = jsonDecode(r.body);
      throw Exception(err['detail'] ?? 'Error al desvincular paciente');
    }
  }

  /// El paciente se desvincula de su logopeda.
  Future<void> desvincularme() async {
    final r = await http
        .delete(Uri.parse('$kServerUrl/roles/desvincularme'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) {
      final err = jsonDecode(r.body);
      throw Exception(err['detail'] ?? 'Error al desvincularse');
    }
  }
}