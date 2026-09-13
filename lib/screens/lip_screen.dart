// lib/screens/lip_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'dart:convert';

import '../models/app_user.dart';
import '../theme/app_theme.dart';
import '../widgets/main_app_bar.dart';
import '../services/api_service.dart'; // para kServerUrl

class LipScreen extends StatefulWidget {
  final AppUser? user;
  final VoidCallback onVozTap;
  final VoidCallback onClasesTap;
  const LipScreen({
    super.key,
    this.user,
    required this.onVozTap,
    required this.onClasesTap,
  });

  @override
  State<LipScreen> createState() => _LipScreenState();
}

class _LipScreenState extends State<LipScreen> with WidgetsBindingObserver {
  AdaptiveColors get c => AdaptiveColors.of(context);

  // ── Cámara ─────────────────────────────────────────────────────
  CameraController? _camCtrl;
  List<CameraDescription> _cameras = [];
  bool _cameraReady = false;
  bool _recording = false;

  // ── Audio ──────────────────────────────────────────────────────
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _playing = false;

  // ── Estado UI ──────────────────────────────────────────────────
  _LipState _state = _LipState.idle;
  String? _errorMsg;
  String? _resultText;
  List<int>? _audioBytes;

  int _recSeconds = 0;
  static const int _maxSeconds = 8;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() => _playing = state.playing);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camCtrl?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _camCtrl;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      ctrl.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  // ── Cámara ─────────────────────────────────────────────────────
  Future<void> _initCamera() async {
    final camStatus = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();

    if (!camStatus.isGranted || !micStatus.isGranted) {
      if (mounted) {
        setState(() => _errorMsg = 'Se necesitan permisos de cámara y micrófono.');
      }
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) setState(() => _errorMsg = 'No se encontraron cámaras.');
        return;
      }

      final front = _cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );

      final ctrl = CameraController(
        front,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await ctrl.initialize();
      await ctrl.setExposureMode(ExposureMode.auto);
      await ctrl.setFocusMode(FocusMode.auto);

      await ctrl.initialize();
      if (!mounted) return;

      setState(() {
        _camCtrl = ctrl;
        _cameraReady = true;
      });
    } catch (e) {
      if (mounted) setState(() => _errorMsg = 'Error al iniciar cámara: $e');
    }
  }

  // ── Grabación ──────────────────────────────────────────────────
  Future<void> _startRecording() async {
    if (_camCtrl == null || !_cameraReady || _recording) return;
    if (_state == _LipState.processing) return;

    setState(() {
      _recording = true;
      _recSeconds = 0;
      _state = _LipState.recording;
      _errorMsg = null;
      _resultText = null;
      _audioBytes = null;
    });

    await _camCtrl!.startVideoRecording();
    _tickSeconds();
  }

  void _tickSeconds() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || !_recording) return;
      setState(() => _recSeconds++);
      if (_recSeconds >= _maxSeconds) {
        _stopAndSend();
      } else {
        _tickSeconds();
      }
    });
  }

  Future<void> _stopAndSend() async {
    if (!_recording) return;
    setState(() {
      _recording = false;
      _state = _LipState.processing;
    });

    XFile? videoFile;
    try {
      videoFile = await _camCtrl!.stopVideoRecording();
    } catch (e) {
      if (mounted) setState(() { _state = _LipState.idle; _errorMsg = 'Error al detener la grabación.'; });
      return;
    }

    try {
      final token = widget.user?.token ?? '';
      final uri = Uri.parse('$kServerUrl/lipreading/speak');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..headers.addAll(kNgrokHeaders)
        ..files.add(await http.MultipartFile.fromPath('video', videoFile.path));

      final streamed = await request.send().timeout(const Duration(seconds: 120));

      if (streamed.statusCode == 200) {
        final bytes = await streamed.stream.toBytes();
        final recognizedText = streamed.headers['x-recognized-text'] ?? '';
        // FIX: decodificación segura para tildes y caracteres especiales
        String decodedText;
        try {
          decodedText = Uri.decodeFull(recognizedText);
        } catch (_) {
          decodedText = recognizedText;
        }
        if (mounted) {
          setState(() {
            _state = _LipState.result;
            _resultText = decodedText;
            _audioBytes = bytes;
          });
          // Reproducir el audio automáticamente
          await _playAudio(bytes);
        }
      } else {
        final body = await streamed.stream.bytesToString();
        String detail = 'Error del servidor (${streamed.statusCode})';
        try {
          detail = jsonDecode(body)['detail'] ?? detail;
        } catch (_) {}
        if (mounted) setState(() { _state = _LipState.error; _errorMsg = detail; });
      }
    } catch (e) {
      if (mounted) setState(() { _state = _LipState.error; _errorMsg = e.toString(); });
    } finally {
      try { await File(videoFile.path).delete(); } catch (_) {}
    }
  }

  Future<void> _playAudio(List<int> bytes) async {
    try {
      final dir = await Directory.systemTemp.createTemp('lip_audio');
      final file = File('${dir.path}/audio.wav');
      await file.writeAsBytes(bytes);
      await _audioPlayer.setFilePath(file.path);
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Error reproduciendo audio: $e');
    }
  }

  void _reset() {
    _audioPlayer.stop();
    setState(() {
      _state = _LipState.idle;
      _errorMsg = null;
      _resultText = null;
      _audioBytes = null;
      _recSeconds = 0;
    });
  }

  // ── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: c.bg,
      appBar: MainAppBar(
        title: 'Labios',
        vozPendiente: !(widget.user?.hasVoice ?? false),
        onVozTap: widget.onVozTap,
        onClasesTap: widget.onClasesTap,
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (!_cameraReady) {
      return _errorMsg != null
          ? _centeredMessage(icon: Icons.videocam_off, text: _errorMsg!)
          : const Center(child: CircularProgressIndicator());
    }

    // FIX: SingleChildScrollView evita el overflow cuando aparece el resultado
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildCameraPreview(),
          const SizedBox(height: 16),
          _buildStatusArea(),
          const SizedBox(height: 24),
          if (_state != _LipState.processing) _buildControls(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    return AspectRatio(
      aspectRatio: _camCtrl!.value.aspectRatio,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CameraPreview(_camCtrl!),
          ),

          // Guía oval de labios
          Positioned(
            bottom: 40,
            child: Container(
              width: 120,
              height: 60,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _recording
                      ? c.warn.withValues(alpha: 0.8)
                      : c.accent.withValues(alpha: 0.5),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(60),
              ),
            ),
          ),

          // Badge grabación
          if (_recording)
            Positioned(
              top: 12,
              right: 12,
              child: _RecordingBadge(seconds: _recSeconds, max: _maxSeconds),
            ),

          // Overlay procesando
          if (_state == _LipState.processing)
            Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Reconociendo...', style: TextStyle(color: Colors.white, fontSize: 14)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusArea() {
    if (_state == _LipState.result && _resultText != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.accent.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Texto reconocido:',
                      style: TextStyle(color: c.textDim, fontSize: 12)),
                  const SizedBox(height: 6),
                  Text(_resultText!,
                      style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Botón de reproducir/parar audio
            if (_audioBytes != null)
              GestureDetector(
                onTap: () async {
                  if (_playing) {
                    await _audioPlayer.stop();
                  } else {
                    await _playAudio(_audioBytes!);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: c.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: c.accent.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_playing ? Icons.stop_rounded : Icons.volume_up_rounded,
                          color: c.accent, size: 20),
                      const SizedBox(width: 8),
                      Text(_playing ? 'Parar' : 'Reproducir',
                          style: TextStyle(color: c.accent, fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }

    if (_state == _LipState.error && _errorMsg != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.warn.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.warn.withValues(alpha: 0.3)),
          ),
          child: Text(_errorMsg!, style: TextStyle(color: c.warn, fontSize: 13)),
        ),
      );
    }

    if (_state == _LipState.idle) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          'Mantén pulsado para grabar. Habla mirando a la cámara.',
          textAlign: TextAlign.center,
          style: TextStyle(color: c.textDim, fontSize: 13),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildControls() {
    if (_state == _LipState.result || _state == _LipState.error) {
      return GestureDetector(
        onTap: _reset,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.accent,
            boxShadow: [
              BoxShadow(color: c.accent.withValues(alpha: 0.4), blurRadius: 12),
            ],
          ),
          child: const Icon(Icons.refresh, color: Colors.black, size: 32),
        ),
      );
    }

    return GestureDetector(
      onTapDown: (_) => _startRecording(),
      onTapUp: (_) { if (_recording) _stopAndSend(); },
      onTapCancel: () { if (_recording) _stopAndSend(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: _recording ? 72 : 80,
        height: _recording ? 72 : 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _recording ? c.warn : c.accent,
          boxShadow: [
            BoxShadow(
              color: (_recording ? c.warn : c.accent).withValues(alpha: 0.4),
              blurRadius: _recording ? 20 : 12,
              spreadRadius: _recording ? 4 : 0,
            ),
          ],
        ),
        child: Icon(
          _recording ? Icons.stop : Icons.videocam,
          color: Colors.black,
          size: 32,
        ),
      ),
    );
  }

  Widget _centeredMessage({required IconData icon, required String text}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: c.textDim),
            const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center,
                style: TextStyle(color: c.textMid, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────

enum _LipState { idle, recording, processing, result, error }

class _RecordingBadge extends StatelessWidget {
  final int seconds;
  final int max;
  const _RecordingBadge({required this.seconds, required this.max});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.circle, color: Colors.red, size: 8),
          const SizedBox(width: 6),
          Text('$seconds / $max s',
              style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}