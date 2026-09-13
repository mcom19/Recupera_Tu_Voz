import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

import '../theme/app_theme.dart';
import '../widgets/voz_menu_card.dart';

// ─────────────────────────────────────────────────────────────────
// Frases guiadas — variedad tonal y fonética en castellano
// ─────────────────────────────────────────────────────────────────
const _kFrases = [
  'El sol brilla con fuerza sobre las montañas nevadas del norte. El viento frío sopla entre los pinos y el silencio solo lo rompe el sonido del río bajando por el valle.',
  'Hoy me siento muy bien y estoy listo para empezar el día con energía. He dormido bien, he desayunado tranquilo y tengo muchas ganas de hacer cosas nuevas.',
  'Por favor, tráeme un vaso de agua fría con un poco de limón. También me gustaría comer algo ligero, quizás una tostada con aceite o un poco de fruta fresca.',
  'Necesito ayuda para llegar al hospital lo antes posible. No me encuentro bien desde esta mañana y me gustaría que alguien me acompañara o llamara a mi médico de cabecera.',
  'Me llamo Lucas y vivo en Redován, un pueblo de Alicante cerca del río Segura. Estudié desarrollo de aplicaciones y me gusta mucho la tecnología, la música y estar al aire libre.',
  'Buenos días a todos. ¿Cómo estáis hoy? Espero que muy bien. Yo he empezado el día con buen humor y con ganas de disfrutar de cada momento junto a las personas que quiero.',
  'La tecnología nos permite comunicarnos de formas increíbles que antes eran imposibles. Gracias a ella, personas que no pueden hablar pueden expresarse y conectar con el mundo que les rodea.',
  'Quiero pedir una pizza margarita con extra de queso y champiñones, por favor. De beber me pone una Coca-Cola bien fría, y de postre, si tiene tiramisú, me lo apunta también.',
  'Gracias por tu ayuda. Sin ti no lo habría conseguido nunca. De verdad que te lo agradezco con todo el corazón. Eres una persona muy importante para mí y siempre lo recordaré.',
  'El perro corre feliz por el parque mientras los niños juegan entre las flores. La tarde es tranquila, el cielo está despejado y se respira ese aire limpio que tanto me gusta.',
  'Mañana tengo una cita importante y estoy algo nervioso, aunque sé que todo va a salir bien. He preparado todo con cuidado y confío en que las cosas irán como espero.',
  'Me gustaría escuchar música tranquila esta tarde en casa, quizás algo de jazz o música clásica. Encender una vela, preparar una infusión caliente y descansar sin pensar en nada más.',
];

// ─────────────────────────────────────────────────────────────────
class RecordVoiceScreen extends StatefulWidget {
  /// Devuelve los bytes WAV grabados y el nombre de fichero sugerido.
  final Future<void> Function(
      List<({Uint8List bytes, String filename})> files,
      {required bool replace}) onRecorded;

  final int currentRefs;
  final int maxRefs;
  final VoidCallback onDone;

  const RecordVoiceScreen({
    super.key,
    required this.onRecorded,
    required this.currentRefs,
    required this.maxRefs,
    required this.onDone,
  });

  @override
  State<RecordVoiceScreen> createState() => _RecordVoiceScreenState();
}

// ─────────────────────────────────────────────────────────────────
class _RecordVoiceScreenState extends State<RecordVoiceScreen>
    with SingleTickerProviderStateMixin {
  AdaptiveColors get c => AdaptiveColors.of(context);

  // ── Servicios ──────────────────────────────────────────────────
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  // ── Estado ─────────────────────────────────────────────────────
  _RecState _state = _RecState.guide;
  int _selectedFrase = 0;
  String? _recordedPath;
  bool _uploading = false;
  String? _error;
  String? _successMsg;

  // Temporizador
  int _recSeconds = 0;
  static const int _minSeconds = 10;
  static const int _maxSeconds = 120;
  bool _ticking = false;

  // Animación del botón pulsante
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  // ── Grabación ──────────────────────────────────────────────────
  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      _setError('Se necesita permiso de micrófono.');
      return;
    }

    final tmpDir = await getTemporaryDirectory();
    final path =
        '${tmpDir.path}/voz_ref_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 22050,
        numChannels: 1,
        bitRate: 128000,
      ),
      path: path,
    );

    setState(() {
      _state = _RecState.recording;
      _recSeconds = 0;
      _ticking = true;
      _error = null;
    });

    _tick();
  }

  void _tick() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || !_ticking) return;
      setState(() => _recSeconds++);
      if (_recSeconds >= _maxSeconds) {
        _stopRecording();
      } else {
        _tick();
      }
    });
  }

  Future<void> _stopRecording() async {
    _ticking = false;
    if (_recSeconds < _minSeconds) {
      await _recorder.stop();
      setState(() {
        _state = _RecState.ready;
        _error =
        'Grabación demasiado corta. Habla al menos $_minSeconds segundos.';
      });
      return;
    }

    final path = await _recorder.stop();
    if (path == null || !mounted) return;

    setState(() {
      _recordedPath = path;
      _state = _RecState.preview;
      _error = null;
    });
  }

  // ── Reproducción ───────────────────────────────────────────────
  Future<void> _playPreview() async {
    if (_recordedPath == null) return;
    await _player.stop();
    await _player.setFilePath(_recordedPath!);
    await _player.play();
  }

  void _retake() {
    _player.stop();
    try {
      if (_recordedPath != null) File(_recordedPath!).deleteSync();
    } catch (_) {}
    setState(() {
      _recordedPath = null;
      _state = _RecState.ready;
      _error = null;
    });
  }

  // ── Subida ─────────────────────────────────────────────────────
  Future<void> _confirm({required bool replace}) async {
    if (_recordedPath == null) return;
    setState(() {
      _uploading = true;
      _error = null;
    });

    try {
      final bytes = await File(_recordedPath!).readAsBytes();
      final filename =
          'grabacion_${DateTime.now().millisecondsSinceEpoch}.wav';

      await widget.onRecorded(
        [(bytes: bytes, filename: filename)],
        replace: replace,
      );

      // Limpiar fichero local
      try {
        File(_recordedPath!).deleteSync();
      } catch (_) {}

      if (mounted) {
        setState(() {
          _uploading = false;
          _successMsg = replace
              ? 'Voz reemplazada correctamente.'
              : 'Audio añadido correctamente.';
          _state = _RecState.done;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _setError(String msg) => setState(() => _error = msg);

  // ── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: c.accent),
          onPressed: () {
            _player.stop();
            _ticking = false;
            _recorder.stop().ignore();
            widget.onDone();
          },
        ),
        title: Text(
          'Grabar mi voz',
          style: TextStyle(color: c.textPrimary, fontSize: 17),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: _buildCurrentState(),
        ),
      ),
    );
  }

  Widget _buildCurrentState() {
    switch (_state) {
      case _RecState.guide:
        return _buildGuide();
      case _RecState.ready:
        return _buildReady();
      case _RecState.recording:
        return _buildRecording();
      case _RecState.preview:
        return _buildPreview();
      case _RecState.done:
        return _buildDone();
    }
  }

  // ── PASO 0: Guía ───────────────────────────────────────────────
  Widget _buildGuide() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.accent.withValues(alpha: 0.12),
              ),
              child: Icon(Icons.mic_rounded, color: c.accent, size: 36),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Consejos para una grabación perfecta',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Consejos
          ..._tips.map((t) => _TipRow(icon: t.$1, text: t.$2, c: c)),
          const SizedBox(height: 28),

          // Calidad según nº audios
          _QualityBar(currentRefs: widget.currentRefs, maxRefs: widget.maxRefs, c: c),
          const SizedBox(height: 32),

          // Botón continuar
          _PrimaryButton(
            label: 'Entendido, vamos a grabar',
            icon: Icons.arrow_forward_rounded,
            color: c.accent,
            onTap: () => setState(() => _state = _RecState.ready),
          ),
        ],
      ),
    );
  }

  static const _tips = [
    (Icons.volume_off_rounded,
    'Busca un lugar silencioso, sin música ni ruido de fondo.'),
    (Icons.phone_android_rounded,
    'Acerca el teléfono a unos 15–20 cm de tu boca.'),
    (Icons.speed_rounded,
    'Habla a tu ritmo normal, ni muy rápido ni muy despacio.'),
    (Icons.timer_outlined,
    'Graba entre 30 segundos y 2 minutos para mejor resultado.'),
    (Icons.repeat_rounded,
    'Puedes repetir palabras o frases si te equivocas, no pasa nada.'),
    (Icons.auto_awesome_rounded,
    'Cuantos más audios subas (hasta 3), mejor será la clonación.'),
  ];

  // ── PASO 1: Elegir frase y grabar ──────────────────────────────
  Widget _buildReady() {
    final slotsLeft = widget.maxRefs - widget.currentRefs;

    return Column(
      children: [
        // Info slots
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: c.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.accent.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: c.accent, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.currentRefs == 0
                      ? 'Vas a grabar tu primer audio de referencia.'
                      : 'Tienes ${widget.currentRefs}/${widget.maxRefs} audios.'
                      '${slotsLeft > 0 ? ' Puedes añadir $slotsLeft más.' : ''}',
                  style: TextStyle(color: c.accent, fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        // Selector de frase
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Text(
                  'Lee esta frase en voz alta',
                  style: TextStyle(
                    color: c.textMid,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              // Frase grande seleccionada
              GestureDetector(
                onTap: () => _cycleFrase(1),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: vozCardDecoration(
                    radius: 16,
                    borderColor: c.accent.withValues(alpha: 0.3),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _kFrases[_selectedFrase],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 18,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.touch_app_rounded,
                              color: c.textDim, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            'Toca para cambiar frase',
                            style: TextStyle(color: c.textDim, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Mini lista de frases
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _kFrases.length,
                  itemBuilder: (_, i) {
                    final sel = i == _selectedFrase;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedFrase = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: sel
                            ? BoxDecoration(
                                color: c.accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: c.accent.withValues(alpha: 0.4)),
                              )
                            : vozCardDecoration(
                                radius: 10,
                                borderColor: c.border.withValues(alpha: 0.4),
                                shadow: false,
                              ),
                        child: Text(
                          _kFrases[i],
                          style: TextStyle(
                            color: sel ? c.accent : c.textMid,
                            fontSize: 12,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.warn, fontSize: 12)),
          ),

        // Botón grabar
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          child: _PrimaryButton(
            label: 'Empezar grabación',
            icon: Icons.mic_rounded,
            color: c.accent,
            onTap: _startRecording,
          ),
        ),
      ],
    );
  }

  void _cycleFrase(int dir) {
    setState(() {
      _selectedFrase =
          (_selectedFrase + dir + _kFrases.length) % _kFrases.length;
    });
  }

  // ── PASO 2: Grabando ───────────────────────────────────────────
  Widget _buildRecording() {
    final canStop = _recSeconds >= _minSeconds;
    final progress = (_recSeconds / _maxSeconds).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),

          // Frase en pantalla
          Container(
            padding: const EdgeInsets.all(20),
            decoration: vozCardDecoration(
              radius: 16,
              borderColor: c.accent.withValues(alpha: 0.2),
            ),
            child: Text(
              _kFrases[_selectedFrase],
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 18,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(height: 40),

          // Botón pulsante
          ScaleTransition(
            scale: _pulseAnim,
            child: GestureDetector(
              onTap: canStop ? _stopRecording : null,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.warn,
                  boxShadow: [
                    BoxShadow(
                      color: c.warn.withValues(alpha: 0.4),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(Icons.stop_rounded,
                    color: Colors.white, size: 40),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Contador
          Text(
            _formatTime(_recSeconds),
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),

          const SizedBox(height: 8),

          // Progreso
          LinearProgressIndicator(
            value: progress,
            backgroundColor: c.border.withValues(alpha: 0.3),
            valueColor: AlwaysStoppedAnimation<Color>(
                canStop ? c.accent : c.warn),
          ),

          const SizedBox(height: 8),

          Text(
            canStop
                ? 'Pulsa para detener  •  máx. ${_formatTime(_maxSeconds)}'
                : 'Mínimo $_minSeconds s  •  sigue hablando…',
            style: TextStyle(color: c.textDim, fontSize: 12),
          ),

          const Spacer(),

          // Cancelar
          TextButton(
            onPressed: () async {
              _ticking = false;
              await _recorder.stop();
              setState(() {
                _state = _RecState.ready;
                _error = null;
                _recSeconds = 0;
              });
            },
            child: Text('Cancelar',
                style: TextStyle(color: c.textDim, fontSize: 13)),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── PASO 3: Vista previa ───────────────────────────────────────
  Widget _buildPreview() {
    final hasSlots = widget.currentRefs < widget.maxRefs;
    final isFirst = widget.currentRefs == 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Duración grabada
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: c.teal.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_outline_rounded,
                color: c.teal, size: 52),
          ),

          const SizedBox(height: 16),

          Text(
            'Grabación completada',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            '${_formatTime(_recSeconds)} grabados',
            style: TextStyle(color: c.textDim, fontSize: 13),
          ),

          const SizedBox(height: 28),

          // Reproducir
          OutlinedButton.icon(
            onPressed: _playPreview,
            icon: Icon(Icons.play_arrow_rounded, color: c.accent),
            label: Text('Escuchar grabación',
                style: TextStyle(color: c.accent)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: c.accent.withValues(alpha: 0.5)),
              padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),

          const SizedBox(height: 32),

          if (_error != null) ...[
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.warn, fontSize: 12)),
            const SizedBox(height: 16),
          ],

          if (_uploading) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text('Subiendo audio…',
                style: TextStyle(color: c.textDim, fontSize: 13)),
          ] else ...[
            // Botón principal: Añadir o Reemplazar
            if (!isFirst && hasSlots)
              _PrimaryButton(
                label: 'Añadir a mis referencias'
                    ' (${widget.currentRefs + 1}/${widget.maxRefs})',
                icon: Icons.add_circle_outline_rounded,
                color: c.accent,
                onTap: () => _confirm(replace: false),
              ),

            if (!isFirst) const SizedBox(height: 12),

            _PrimaryButton(
              label: isFirst
                  ? 'Guardar y clonar mi voz'
                  : 'Reemplazar todo con este audio',
              icon: isFirst
                  ? Icons.save_alt_rounded
                  : Icons.swap_horiz_rounded,
              color: isFirst ? c.accent : c.warn,
              onTap: () => _confirm(replace: true),
              outline: !isFirst,
            ),

            const SizedBox(height: 16),

            // Volver a grabar
            TextButton.icon(
              onPressed: _retake,
              icon: Icon(Icons.refresh_rounded, color: c.textDim, size: 16),
              label: Text('Volver a grabar',
                  style: TextStyle(color: c.textDim, fontSize: 13)),
            ),
          ],
        ],
      ),
    );
  }

  // ── PASO 4: Éxito ──────────────────────────────────────────────
  Widget _buildDone() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.teal.withValues(alpha: 0.12),
              ),
              child: Icon(Icons.check_rounded, color: c.teal, size: 44),
            ),
            const SizedBox(height: 20),
            Text(
              _successMsg ?? '¡Listo!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tu voz se ha guardado como referencia para la clonación.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textMid, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 32),
            _PrimaryButton(
              label: 'Volver a ajustes de voz',
              icon: Icons.arrow_back_rounded,
              color: c.accent,
              onTap: widget.onDone,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() {
                _state = _RecState.ready;
                _recordedPath = null;
                _successMsg = null;
                _error = null;
                _recSeconds = 0;
              }),
              child: Text(
                'Grabar otro audio',
                style: TextStyle(color: c.textDim, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────
  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────────────────────────
// Subwidgets
// ─────────────────────────────────────────────────────────────────

enum _RecState { guide, ready, recording, preview, done }

class _TipRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final AdaptiveColors c;
  const _TipRow({required this.icon, required this.text, required this.c});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.accent.withValues(alpha: 0.1),
            ),
            child: Icon(icon, color: c.accent, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(text,
                  style:
                  TextStyle(color: c.textMid, fontSize: 13, height: 1.4)),
            ),
          ),
        ],
      ),
    );
  }
}

class _QualityBar extends StatelessWidget {
  final int currentRefs;
  final int maxRefs;
  final AdaptiveColors c;
  const _QualityBar(
      {required this.currentRefs, required this.maxRefs, required this.c});

  @override
  Widget build(BuildContext context) {
    final labels = ['Básico', 'Bueno', 'Óptimo'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: vozCardDecoration(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Calidad de clonación',
                  style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              Text(
                currentRefs == 0
                    ? 'Sin audios aún'
                    : labels[(currentRefs - 1).clamp(0, 2)],
                style: TextStyle(
                    color: c.accent, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(maxRefs, (i) {
              final filled = i < currentRefs;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < maxRefs - 1 ? 6 : 0),
                  height: 7,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: filled
                        ? c.accent
                        : c.accent.withValues(alpha: 0.15),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            currentRefs == 0
                ? 'Graba al menos 1 audio para empezar.'
                : currentRefs < maxRefs
                ? 'Añade ${maxRefs - currentRefs} audio${maxRefs - currentRefs == 1 ? '' : 's'} más para calidad máxima.'
                : '¡Tienes todos los audios! Calidad máxima.',
            style: TextStyle(color: c.textDim, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool outline;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.outline = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: outline ? Colors.transparent : color,
          borderRadius: BorderRadius.circular(12),
          border: outline
              ? Border.all(color: color.withValues(alpha: 0.55))
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: outline ? color : Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: outline ? color : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}