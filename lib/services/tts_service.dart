import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import '../models/app_settings.dart';
import '../models/voz_emocion.dart';
import 'api_service.dart';
import 'audio_cache_service.dart';

class TtsService {
  final VoiceApiService _api = VoiceApiService();
  final AudioPlayer _player = AudioPlayer();
  final FlutterTts _systemTts = FlutterTts();

  bool _isSpeaking = false;
  bool get isSpeaking => _isSpeaking;

  Function()? onDone;
  Function(String)? onError;

  Future<void> init() async {
    _systemTts.setCompletionHandler(() { _isSpeaking = false; onDone?.call(); });
    _systemTts.setCancelHandler(() { _isSpeaking = false; onDone?.call(); });
    _systemTts.setErrorHandler((msg) { _isSpeaking = false; onError?.call(msg); });
    try {
      final langs = await _systemTts.getLanguages as List?;
      final hasEs = langs?.any((l) => l.toString().toLowerCase().contains('es')) ?? false;
      await _systemTts.setLanguage(hasEs ? 'es-ES' : 'en-US');
    } catch (_) {
      await _systemTts.setLanguage('es-ES');
    }
    await _systemTts.setVolume(1.0);
    await _systemTts.setSpeechRate(0.5);
    await _systemTts.setPitch(1.0);
    await _systemTts.awaitSpeakCompletion(true);
  }

  /// Devuelve false si ya hay síntesis en curso (petición ignorada).
  /// Devuelve true cuando termina correctamente.
  Future<bool> speak({
    required String text,
    required AppSettings settings,
    required String? userToken,
    required bool hasVoice,
    VozEmocion emocion = VozEmocion.neutral,
    // Necesario para el caché de audio (namespacing por usuario). Si no se
    // pasa, simplemente no se cachea nada — sigue funcionando igual que antes.
    String? userId,
  }) async {
    // ── Bloqueo: ignorar si ya está procesando ────────────────────
    if (_isSpeaking) return false;
    _isSpeaking = true;

    try {
      if (userToken != null && hasVoice) {
        final speed = (settings.velocidad + 0.5).clamp(0.5, 2.0);

        // ── Caché: si ya se sintetizó este texto con esta voz/velocidad,
        // reproducirlo al instante en vez de volver a llamar al backend
        // (la síntesis con OpenVoice puede tardar hasta 60s).
        Uint8List? bytes;
        if (userId != null) {
          bytes = await AudioCacheService.get(userId: userId, text: text, speed: speed);
        }

        if (bytes == null) {
          bytes = await _api.synthesize(token: userToken, text: text, speed: speed);
          if (userId != null) {
            // No hace falta esperar a que termine de escribir en disco.
            unawaited(AudioCacheService.put(
              userId: userId, text: text, speed: speed, bytes: bytes,
            ));
          }
        }

        await _playBytes(bytes, volume: settings.volumen);
        _isSpeaking = false;
        onDone?.call();
      } else {
        final (pitch, rate) = emocion.browserTtsParams;
        final finalRate = (settings.velocidad * rate * 2).clamp(0.1, 1.0);
        await _systemTts.setSpeechRate(finalRate);
        await _systemTts.setVolume(settings.volumen);
        await _systemTts.setPitch(pitch);
        final result = await _systemTts.speak(text);
        if (result != 1) {
          _isSpeaking = false;
          onError?.call('Error de voz del sistema');
        }
      }
      return true;
    } on ApiException catch (e) {
      _isSpeaking = false;
      onError?.call(e.message);
      return false;
    } catch (e) {
      _isSpeaking = false;
      onError?.call('Error de voz: $e');
      return false;
    }
  }

  Future<void> _playBytes(Uint8List bytes, {double volume = 1.0}) async {
    await _player.stop();
    await _player.setAudioSource(_BytesSource(bytes));
    await _player.setVolume(volume);
    await _player.play();
    await _player.processingStateStream.firstWhere(
          (s) => s == ProcessingState.completed || s == ProcessingState.idle,
    );
  }

  Future<void> stop() async {
    _isSpeaking = false;
    await _player.stop();
    await _systemTts.stop();
  }

  void dispose() {
    _player.dispose();
    _systemTts.stop();
  }
}

class _BytesSource extends StreamAudioSource {
  final Uint8List _b;
  _BytesSource(this._b);
  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _b.length;
    // El backend ahora devuelve WAV — cambiamos el contentType
    return StreamAudioResponse(
      sourceLength: _b.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(List<int>.from(_b.sublist(start, end))),
      contentType: 'audio/wav',
    );
  }
}