// lib/screens/lip_capture_prototype_screen.dart
//
// Prototipo de captura para lectura de labios CON encuadre facial en
// tiempo real (Google ML Kit) — evolución de lip_screen.dart.
//
// Diferencias frente a lip_screen.dart (que ya existe en el proyecto):
//   1. Mientras se apunta con la cámara, se ejecuta detección facial en
//      vivo (ver services/face_framing_service.dart) y se colorea el
//      óvalo-guía en verde/ámbar/rojo según si la boca está bien
//      encuadrada — en vez de un óvalo estático decorativo.
//   2. Si el backend responde a `POST /lipreading/speak` (el mismo
//      contrato que ya usa lip_screen.dart), se reproduce el resultado
//      real. Si el backend aún no expone ese endpoint (es el caso
//      actual del proyecto: falta el router de lipreading), el
//      prototipo cae automáticamente a un "modo demo" que guarda el
//      vídeo localmente y lo indica en pantalla — así se puede probar
//      y enseñar el flujo de encuadre + grabación de extremo a extremo
//      sin esperar al backend, y el día que el endpoint exista
//      empezará a funcionar en real sin tocar este archivo.
//
// Integración futura: cuando el backend esté listo, esta pantalla
// puede sustituir directamente a lip_screen.dart (mismo contrato de
// red, mismo AppUser, mismo AdaptiveColors) o convivir con ella detrás
// de un flag mientras se compara precisión/latencia.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/app_user.dart';
import '../services/api_service.dart'; // kServerUrl, kNgrokHeaders
import '../services/face_framing_service.dart';
import '../theme/app_theme.dart';
import '../widgets/mouth_frame_overlay.dart';

class LipCapturePrototypeScreen extends StatefulWidget {
  final AppUser? user;
  const LipCapturePrototypeScreen({super.key, this.user});

  @override
  State<LipCapturePrototypeScreen> createState() => _LipCapturePrototypeScreenState();
}

enum _Estado { iniciando, apuntando, grabando, procesando, resultado, error }

class _LipCapturePrototypeScreenState extends State<LipCapturePrototypeScreen>
    with WidgetsBindingObserver {
  AdaptiveColors get c => AdaptiveColors.of(context);

  CameraController? _camCtrl;
  CameraDescription? _camDesc;
  final FaceFramingService _framing = FaceFramingService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  _Estado _estado = _Estado.iniciando;
  FramingState _framingState = FramingState.inicial;
  bool _streamingFrames = false;
  bool _demoLocalForzado = false; // toggle manual desde la AppBar

  String? _errorMsg;
  String? _resultText;
  List<int>? _audioBytes;
  String? _rutaVideoLocal;

  int _recSeconds = 0;
  Timer? _recTimer;
  static const int _maxSeconds = 8;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audioPlayer.playerStateStream.listen((_) {
      if (mounted) setState(() {});
    });
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recTimer?.cancel();
    _stopFrameStream();
    _camCtrl?.dispose();
    _framing.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _camCtrl;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _stopFrameStream();
      ctrl.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _init();
    }
  }

  // ── Inicialización ────────────────────────────────────────────────
  Future<void> _init() async {
    setState(() => _estado = _Estado.iniciando);

    final camStatus = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();
    if (!camStatus.isGranted || !micStatus.isGranted) {
      setState(() {
        _estado = _Estado.error;
        _errorMsg = 'Se necesitan permisos de cámara y micrófono.';
      });
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _estado = _Estado.error;
          _errorMsg = 'No se encontraron cámaras.';
        });
        return;
      }
      final front = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _camDesc = front;

      final ctrl = CameraController(
        front,
        ResolutionPreset.high,
        enableAudio: false,
        // Formato requerido por FaceFramingService para poder construir
        // el InputImage de ML Kit sin concatenar planos manualmente.
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );
      await ctrl.initialize();
      await ctrl.setExposureMode(ExposureMode.auto);
      await ctrl.setFocusMode(FocusMode.auto);
      if (!mounted) return;

      setState(() {
        _camCtrl = ctrl;
        _estado = _Estado.apuntando;
      });
      _startFrameStream();
    } catch (e) {
      setState(() {
        _estado = _Estado.error;
        _errorMsg = 'Error al iniciar la cámara: $e';
      });
    }
  }

  // ── Encuadre en vivo ─────────────────────────────────────────────
  void _startFrameStream() {
    final ctrl = _camCtrl;
    final camDesc = _camDesc;
    if (ctrl == null || camDesc == null || _streamingFrames) return;
    _streamingFrames = true;
    ctrl.startImageStream((image) async {
      if (!_streamingFrames) return;
      final result = await _framing.processCameraImage(
        image: image,
        camera: camDesc,
        deviceOrientation: ctrl.value.deviceOrientation,
      );
      if (result != null && mounted) {
        setState(() => _framingState = result);
      }
    });
  }

  Future<void> _stopFrameStream() async {
    if (!_streamingFrames) return;
    _streamingFrames = false;
    try {
      await _camCtrl?.stopImageStream();
    } catch (_) {
      // Puede lanzar si la cámara ya no está activa; se ignora.
    }
  }

  // ── Grabación ────────────────────────────────────────────────────
  Future<void> _startRecording() async {
    if (_camCtrl == null || _estado != _Estado.apuntando) return;

    await _stopFrameStream(); // no se puede grabar vídeo y leer el stream a la vez
    await _camCtrl!.startVideoRecording();

    setState(() {
      _estado = _Estado.grabando;
      _recSeconds = 0;
      _errorMsg = null;
      _resultText = null;
      _audioBytes = null;
      _rutaVideoLocal = null;
    });

    _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _recSeconds++);
      if (_recSeconds >= _maxSeconds) _stopAndProcess();
    });
  }

  Future<void> _stopAndProcess() async {
    if (_estado != _Estado.grabando) return;
    _recTimer?.cancel();
    setState(() => _estado = _Estado.procesando);

    XFile? videoFile;
    try {
      videoFile = await _camCtrl!.stopVideoRecording();
    } catch (e) {
      setState(() {
        _estado = _Estado.error;
        _errorMsg = 'Error al detener la grabación: $e';
      });
      _startFrameStream();
      return;
    }

    _rutaVideoLocal = videoFile.path;

    if (!_demoLocalForzado) {
      final ok = await _enviarABackend(videoFile);
      if (ok) {
        _startFrameStream();
        return;
      }
    }

    // Modo demo: no hay backend de lectura de labios todavía (o se ha
    // forzado el modo local). El vídeo queda guardado para poder
    // inspeccionarlo o subirlo a mano.
    if (mounted) {
      setState(() {
        _estado = _Estado.resultado;
        _resultText = null;
        _audioBytes = null;
      });
    }
    _startFrameStream();
  }

  /// Intenta subir el vídeo a `/lipreading/speak`. Devuelve `true` si
  /// obtuvo una respuesta válida (y ya ha actualizado el estado con el
  /// resultado real); `false` si hay que caer al modo demo local.
  Future<bool> _enviarABackend(XFile videoFile) async {
    try {
      final token = widget.user?.token ?? '';
      final uri = Uri.parse('$kServerUrl/lipreading/speak');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..headers.addAll(kNgrokHeaders)
        ..files.add(await http.MultipartFile.fromPath('video', videoFile.path));

      final streamed = await request.send().timeout(const Duration(seconds: 15));
      if (streamed.statusCode != 200) return false;

      final bytes = await streamed.stream.toBytes();
      final recognizedRaw = streamed.headers['x-recognized-text'] ?? '';
      String recognized;
      try {
        recognized = Uri.decodeFull(recognizedRaw);
      } catch (_) {
        recognized = recognizedRaw;
      }

      if (!mounted) return true;
      setState(() {
        _estado = _Estado.resultado;
        _resultText = recognized;
        _audioBytes = bytes;
      });
      await _reproducirAudio(bytes);
      return true;
    } catch (_) {
      // Sin conexión, timeout, 404 (endpoint aún no existe), etc.
      // Se resuelve en modo demo local desde _stopAndProcess.
      return false;
    }
  }

  Future<void> _reproducirAudio(List<int> bytes) async {
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
      _estado = _Estado.apuntando;
      _errorMsg = null;
      _resultText = null;
      _audioBytes = null;
      _rutaVideoLocal = null;
      _recSeconds = 0;
    });
  }

  // ── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        title: Text('Lectura de labios (prototipo)', style: TextStyle(color: c.textPrimary)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: _demoLocalForzado
                ? 'Modo demo local forzado (no llama al backend)'
                : 'Intentar backend real primero',
            icon: Icon(_demoLocalForzado ? Icons.cloud_off : Icons.cloud_queue, color: c.textDim),
            onPressed: () => setState(() => _demoLocalForzado = !_demoLocalForzado),
          ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_estado == _Estado.iniciando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_estado == _Estado.error && _camCtrl == null) {
      return _mensajeCentrado(icon: Icons.videocam_off, texto: _errorMsg ?? 'Error desconocido');
    }
    if (_camCtrl == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildCameraPreview(),
          const SizedBox(height: 16),
          _buildStatusArea(),
          const SizedBox(height: 24),
          if (_estado != _Estado.procesando) _buildControls(),
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
          MouthFrameOverlay(
            state: _framingState,
            recording: _estado == _Estado.grabando,
            colorBueno: c.teal,
            colorAjustando: c.gold,
            colorSinRostro: c.warn,
          ),
          if (_estado == _Estado.grabando)
            Positioned(
              top: 12,
              right: 12,
              child: _BadgeGrabando(segundos: _recSeconds, maximo: _maxSeconds),
            ),
          if (_estado == _Estado.apuntando)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: _BadgeEncuadre(mensaje: _framingState.mensaje, color: _colorEncuadreActual()),
            ),
          if (_estado == _Estado.procesando)
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

  Color _colorEncuadreActual() {
    switch (_framingState.quality) {
      case FramingQuality.buena:
        return c.teal;
      case FramingQuality.sinRostro:
        return c.warn;
      default:
        return c.gold;
    }
  }

  Widget _buildStatusArea() {
    if (_estado == _Estado.resultado) {
      final esResultadoReal = _resultText != null;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (esResultadoReal ? c.accent : c.gold).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: (esResultadoReal ? c.accent : c.gold).withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    esResultadoReal ? 'Texto reconocido:' : 'Modo demo — sin backend de lectura de labios',
                    style: TextStyle(color: c.textDim, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    esResultadoReal
                        ? _resultText!
                        : 'Vídeo guardado localmente en:\n${_rutaVideoLocal ?? "(desconocido)"}',
                    style: TextStyle(color: c.textPrimary, fontSize: esResultadoReal ? 16 : 13),
                  ),
                ],
              ),
            ),
            if (_audioBytes != null) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  if (_audioPlayer.playing) {
                    await _audioPlayer.stop();
                  } else {
                    await _reproducirAudio(_audioBytes!);
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
                      Icon(_audioPlayer.playing ? Icons.stop_rounded : Icons.volume_up_rounded,
                          color: c.accent, size: 20),
                      const SizedBox(width: 8),
                      Text(_audioPlayer.playing ? 'Parar' : 'Reproducir',
                          style: TextStyle(color: c.accent, fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (_estado == _Estado.error && _errorMsg != null) {
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

    if (_estado == _Estado.apuntando) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          'Mantén pulsado para grabar cuando el óvalo esté en verde.',
          textAlign: TextAlign.center,
          style: TextStyle(color: c.textDim, fontSize: 13),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildControls() {
    if (_estado == _Estado.resultado || _estado == _Estado.error) {
      return GestureDetector(
        onTap: _reset,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.accent,
            boxShadow: [BoxShadow(color: c.accent.withValues(alpha: 0.4), blurRadius: 12)],
          ),
          child: const Icon(Icons.refresh, color: Colors.black, size: 32),
        ),
      );
    }

    final grabando = _estado == _Estado.grabando;
    return GestureDetector(
      onTapDown: (_) => _startRecording(),
      onTapUp: (_) {
        if (grabando) _stopAndProcess();
      },
      onTapCancel: () {
        if (grabando) _stopAndProcess();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: grabando ? 72 : 80,
        height: grabando ? 72 : 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: grabando ? c.warn : c.accent,
          boxShadow: [
            BoxShadow(
              color: (grabando ? c.warn : c.accent).withValues(alpha: 0.4),
              blurRadius: grabando ? 20 : 12,
              spreadRadius: grabando ? 4 : 0,
            ),
          ],
        ),
        child: Icon(grabando ? Icons.stop : Icons.videocam, color: Colors.black, size: 32),
      ),
    );
  }

  Widget _mensajeCentrado({required IconData icon, required String texto}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: c.textDim),
            const SizedBox(height: 16),
            Text(texto, textAlign: TextAlign.center, style: TextStyle(color: c.textMid, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _BadgeGrabando extends StatelessWidget {
  final int segundos;
  final int maximo;
  const _BadgeGrabando({required this.segundos, required this.maximo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.circle, color: Colors.red, size: 8),
          const SizedBox(width: 6),
          Text('$segundos / $maximo s', style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}

class _BadgeEncuadre extends StatelessWidget {
  final String mensaje;
  final Color color;
  const _BadgeEncuadre({required this.mensaje, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.face_retouching_natural, color: color, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              mensaje,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
