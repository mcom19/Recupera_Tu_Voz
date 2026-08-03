import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

/// Caché local de audio ya sintetizado con la voz clonada.
///
/// Sintetizar con OpenVoice/MeloTTS en el backend es lento (puede tardar
/// hasta 60s). En la pestaña de Frases se repiten las mismas frases una y
/// otra vez — con este caché, la segunda vez que se toca una frase ya dicha
/// antes con la misma voz y velocidad, se reproduce al instante desde disco
/// en vez de volver a llamar al servidor.
///
/// En web no hay acceso a disco real (dart:io no funciona ahí): las
/// operaciones de fichero fallan en tiempo de ejecución y quedan
/// capturadas por los try/catch de abajo, así que en Chrome simplemente
/// no se cachea nada y la app sigue funcionando como antes. En Android/iOS
/// sí hay disco real y el caché funciona.
class AudioCacheService {
  static Directory? _dir;

  static Future<Directory> _cacheDir() async {
    if (_dir != null) return _dir!;
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/tts_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _dir = dir;
    return dir;
  }

  static String _key(String userId, String text, double speed) {
    // Object.hash() es el hash "oficial" de Dart: funciona igual (y sin
    // problemas de precisión) en todas las plataformas, a diferencia de
    // un hash hecho a mano con literales de 64 bits, que en Flutter Web
    // no se pueden representar exactamente en JavaScript.
    final h = Object.hash(userId, text, speed.toStringAsFixed(2));
    return h.abs().toRadixString(16);
  }

  /// Devuelve el audio cacheado para este texto/velocidad/usuario, o null
  /// si no existe todavía (o si no hay disco real, como en web).
  static Future<Uint8List?> get({
    required String userId,
    required String text,
    required double speed,
  }) async {
    try {
      final dir = await _cacheDir();
      final file = File('${dir.path}/${_key(userId, text, speed)}.audio');
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (_) {
      // Caché best-effort: si falla (p.ej. en web), simplemente no había caché.
    }
    return null;
  }

  /// Guarda el audio recién sintetizado para reutilizarlo la próxima vez.
  static Future<void> put({
    required String userId,
    required String text,
    required double speed,
    required Uint8List bytes,
  }) async {
    try {
      final dir = await _cacheDir();
      final file = File('${dir.path}/${_key(userId, text, speed)}.audio');
      await file.writeAsBytes(bytes, flush: true);
    } catch (_) {
      // Si no se puede escribir a disco, no pasa nada: simplemente no
      // se cachea y la próxima vez se vuelve a sintetizar.
    }
  }

  /// Borra todo el caché de audio. Hay que llamarlo cuando el usuario
  /// añade, reemplaza o elimina su voz clonada — si no, se podría
  /// reproducir audio cacheado con la voz antigua.
  static Future<void> clearAll() async {
    try {
      final dir = await _cacheDir();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      _dir = null;
    } catch (_) {}
  }
}
