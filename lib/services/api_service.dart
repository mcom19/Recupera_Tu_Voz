import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:recupera_tu_voz/models/frase_item.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/app_user.dart';

const String kServerUrl = 'https://mirian-eriophyllous-serriedly.ngrok-free.dev';

/// Cabecera necesaria porque el backend está detrás de un túnel ngrok
/// gratuito: sin ella, ngrok devuelve una página HTML de aviso en vez de
/// dejar pasar la petición a la API (falla especialmente en Flutter Web,
/// donde las peticiones llevan cabeceras de navegador).
/// Quitar/vaciar esto cuando se sirva desde un dominio propio.
const Map<String, String> kNgrokHeaders = {'ngrok-skip-browser-warning': 'true'};

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

// ─────────────────────────────────────────────────────────────────
// AUTH SERVICE
// ─────────────────────────────────────────────────────────────────
class AuthService {
  static const _keyToken = 'auth_token';
  static const _keyUser  = 'saved_user';

  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ── REGISTER ───────────────────────────────────────────────────
  Future<AppUser> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final res = await http.post(
      Uri.parse('$kServerUrl/auth/register'),
      headers: {'Content-Type': 'application/json', ...kNgrokHeaders},
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
        'name': name.trim(),
      }),
    ).timeout(const Duration(seconds: 15));

    return _parseAuth(res);
  }

  // ── LOGIN EMAIL ────────────────────────────────────────────────
  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$kServerUrl/auth/login'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded', ...kNgrokHeaders},
      body: 'username=${Uri.encodeComponent(email.trim())}'
          '&password=${Uri.encodeComponent(password)}',
    ).timeout(const Duration(seconds: 15));
    return _parseAuth(res);
  }

  // ── LOGIN GOOGLE ───────────────────────────────────────────────
  Future<AppUser> loginWithGoogle(String idToken) async {
    final res = await http.post(
      Uri.parse('$kServerUrl/auth/google'),
      headers: {'Content-Type': 'application/json', ...kNgrokHeaders},
      body: jsonEncode({'id_token': idToken}),
    ).timeout(const Duration(seconds: 15));

    return _parseAuth(res);
  }

  // ── PERSISTENCIA SEGURA ────────────────────────────────────────
  /// Guardamos token en secure storage + resto sin token en prefs
  Future<void> saveUser(AppUser user) async {
    await _secure.write(key: _keyToken, value: user.token);
    ///sin secure ya que no importa el resto de la info
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyUser, jsonEncode(user.toJsonWithoutToken()));
  }

  /// Cargamos usuario reconstruyendo token + datos
  Future<AppUser?> loadUser() async {
    final token = await _secure.read(key: _keyToken);
    if (token == null || token.isEmpty) return null;

    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_keyUser);
    if (raw == null) return null;

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      map['token'] = token;
      return AppUser.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Logout limpio
  Future<void> logout() async {
    await _secure.delete(key: _keyToken);

    final p = await SharedPreferences.getInstance();
    await p.remove(_keyUser);
  }

  // ── INTERNO ────────────────────────────────────────────────────
  AppUser _parseAuth(http.Response res) {
    if (res.statusCode == 200 || res.statusCode == 201) {
      return AppUser.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
    }
    throw ApiException(
      _extractDetail(res),
      statusCode: res.statusCode,
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// VOICE API SERVICE
// ─────────────────────────────────────────────────────────────────
class VoiceApiService {
  Map<String, String> _headers(String token) => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
    ...kNgrokHeaders,
  };

  Future<Map<String, dynamic>> checkVoiceStatusFull(String token) async {
    try {
      final res = await http
          .get(Uri.parse('$kServerUrl/voice/status'), headers: _headers(token))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}

    return {'has_voice': false, 'num_references': 0};
  }

  Future<bool> checkVoiceStatus(String token) async {
    final d = await checkVoiceStatusFull(token);
    return d['has_voice'] as bool? ?? false;
  }

  Future<int> uploadReplaceAudios({
    required String token,
    required List<({Uint8List bytes, String filename})> files,
  }) async {
    await deleteVoice(token);

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$kServerUrl/voice/upload-multiple'),
    )
      ..headers['Authorization'] = 'Bearer $token'
      ..headers.addAll(kNgrokHeaders);

    for (final f in files) {
      request.files.add(
        http.MultipartFile.fromBytes('files', f.bytes, filename: f.filename),
      );
    }

    final streamed = await request.send().timeout(const Duration(seconds: 120));
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode != 200) {
      throw ApiException(_extractDetail(res), statusCode: res.statusCode);
    }

    final d = jsonDecode(res.body) as Map<String, dynamic>;
    return d['num_references'] as int? ?? files.length;
  }

  Future<int> uploadAddAudios({
    required String token,
    required List<({Uint8List bytes, String filename})> files,
  }) async {
    int lastTotal = 0;

    for (final f in files) {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$kServerUrl/voice/upload'),
      )
        ..headers['Authorization'] = 'Bearer $token'
        ..headers.addAll(kNgrokHeaders)
        ..files.add(
          http.MultipartFile.fromBytes('file', f.bytes, filename: f.filename),
        );

      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final res = await http.Response.fromStream(streamed);

      if (res.statusCode != 200) {
        throw ApiException(_extractDetail(res), statusCode: res.statusCode);
      }

      final d = jsonDecode(res.body) as Map<String, dynamic>;
      lastTotal = d['num_references'] as int? ?? lastTotal + 1;
    }

    return lastTotal;
  }

  Future<Uint8List> synthesize({
    required String token,
    required String text,
    double speed = 1.0,
  }) async {
    final res = await http
        .post(
      Uri.parse('$kServerUrl/voice/tts'),
      headers: _headers(token),
      body: jsonEncode({'text': text, 'speed': speed}),
    )
        .timeout(const Duration(seconds: 90));

    if (res.statusCode == 200) return res.bodyBytes;

    throw ApiException(_extractDetail(res), statusCode: res.statusCode);
  }

  Future<void> deleteVoice(String token) async {
    final res = await http
        .delete(Uri.parse('$kServerUrl/voice/'), headers: _headers(token))
        .timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) {
      throw ApiException(_extractDetail(res), statusCode: res.statusCode);
    }
  }
}

// ─────────────────────────────────────────────────────────────────
// FRASES API SERVICE
// ─────────────────────────────────────────────────────────────────
class FrasesApiService {
  static const _cacheKey     = 'frases_default_cache';
  static const _cacheTimeKey = 'frases_default_cache_time';
  static const _ttlHours     = 24; // caché válida 24 horas
  static const _bundledAsset = 'assets/data/frases_base.json';

  /// Si `fetchDefault()` tuvo que recurrir al catálogo básico embebido
  /// en la app (sin red y sin caché aprovechable) en su última llamada.
  /// La pantalla lo usa para avisar de que se está viendo el catálogo
  /// reducido, no la lista completa del servidor.
  bool lastUsedBundledFallback = false;

  /// Devuelve las frases del servidor, con caché local de 24 h. Si no
  /// hay red y tampoco hay caché aprovechable (p. ej. primer arranque
  /// de un paciente recién dado de alta, con el servidor caído en ese
  /// momento), recurre al catálogo básico embebido en la app —
  /// `loadBundledDefault()`— para que nunca se quede sin frases.
  Future<List<FraseItem>> fetchDefault() async {
    lastUsedBundledFallback = false;
    final p = await SharedPreferences.getInstance();

    // ¿Tenemos caché válida?
    final savedAt = p.getInt(_cacheTimeKey) ?? 0;
    final age = DateTime.now().millisecondsSinceEpoch - savedAt;
    final cacheValid = age < _ttlHours * 3600 * 1000;

    if (cacheValid) {
      final raw = _safeGetCache(p);
      if (raw != null) return _parse(raw);
    }

    // Intentar red
    try {
      final res = await http
          .get(Uri.parse('$kServerUrl/frases/default'), headers: kNgrokHeaders)
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        // Guardar caché
        await p.setString(_cacheKey, res.body);
        await p.setInt(_cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
        return _parse(res.body);
      }
    } catch (_) {
      // Sin red → caer al fallback
    }

    // Caché expirada pero aprovechable: mejor una lista desactualizada
    // que ninguna.
    final stale = _safeGetCache(p);
    if (stale != null) return _parse(stale);

    // Último recurso: catálogo básico embebido en la app (ni red ni
    // caché disponibles).
    lastUsedBundledFallback = true;
    return loadBundledDefault();
  }

  /// Catálogo básico de frases por categoría, empaquetado como asset
  /// de la app: no depende de red ni de una caché previa. Es un
  /// borrador inicial (pendiente de revisión por la logopeda del
  /// proyecto) pensado solo como red de seguridad — no sustituye al
  /// catálogo completo del servidor, evita que la app se quede sin
  /// frases cuando no hay ninguna otra fuente disponible.
  Future<List<FraseItem>> loadBundledDefault() async {
    final raw = await rootBundle.loadString(_bundledAsset);
    return _parse(raw);
  }

  /// Lee la caché de frases protegiendo frente a un valor de tipo
  /// incorrecto bajo la misma clave (defensivo: una versión anterior
  /// de la app llegó a guardar ahí un dato de otro tipo).
  String? _safeGetCache(SharedPreferences p) {
    try {
      return p.getString(_cacheKey);
    } catch (_) {
      return null;
    }
  }

  List<FraseItem> _parse(String json) {
    final list = jsonDecode(json) as List<dynamic>;
    return list
        .map((e) => FraseItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

class VideosApiService {
  final String token;
  const VideosApiService(this.token);

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $token',
    ...kNgrokHeaders,
  };

  Future<Map<String, dynamic>> uploadVideo({
    required Uint8List bytes,
    required String filename,
    required String title,
    required String contentType, // "general" | "demo_ejercicio" | ...
    String visibility = 'todos',
    int? level,
    String? description,
  }) async {
    final uri = Uri.parse(
      '$kServerUrl/videos/upload'
          '?title=${Uri.encodeComponent(title)}'
          '&content_type=$contentType'
          '&visibility=$visibility'
          '${level != null ? "&level=$level" : ""}'
          '${description != null ? "&description=${Uri.encodeComponent(description)}" : ""}',
    );

    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers.addAll(kNgrokHeaders)
      ..files.add(http.MultipartFile.fromBytes(
        'file', bytes, filename: filename,
      ));

    final streamed = await request.send().timeout(const Duration(seconds: 120));
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode != 201) {
      throw ApiException(_extractDetail(res), statusCode: res.statusCode);
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listarVideos({int? level}) async {
    final uri = Uri.parse(
      '$kServerUrl/videos${level != null ? "?level=$level" : ""}',
    );
    final res = await http
        .get(uri, headers: {..._headers, 'Content-Type': 'application/json'})
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw ApiException(_extractDetail(res));
    return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
  }
}
// ─────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────
String _extractDetail(http.Response res) {
  try {
    final b = jsonDecode(res.body) as Map<String, dynamic>;
    return b['detail'] as String? ?? 'Error ${res.statusCode}';
  } catch (_) {
    return 'Error ${res.statusCode}';
  }
}