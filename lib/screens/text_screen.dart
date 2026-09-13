import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/app_settings.dart';
import '../models/app_user.dart';
import '../models/voz_emocion.dart';
import '../services/tts_service.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/main_app_bar.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/voz_menu_card.dart';

class TextScreen extends StatefulWidget {
  final AppSettings settings;
  final AppUser? user;
  final VoidCallback onVozTap;
  final VoidCallback onClasesTap;
  const TextScreen({
    super.key,
    required this.settings,
    this.user,
    required this.onVozTap,
    required this.onClasesTap,
  });

  @override
  State<TextScreen> createState() => _TextScreenState();
}

class _TextScreenState extends State<TextScreen> {
  AdaptiveColors get c => AdaptiveColors.of(context);

  final TextEditingController _controller = TextEditingController();
  late final TtsService _tts;

  bool _isSpeaking = false;
  bool _isLoading = false;
  bool _isSharing = false;
  bool _showControls = false;
  VozEmocion _emocion = VozEmocion.neutral;
  late double _velocidad;
  late double _volumen;

  @override
  void initState() {
    super.initState();
    _velocidad = widget.settings.velocidad;
    _volumen = widget.settings.volumen;
    _tts = TtsService();
    _tts.onDone = () { if (mounted) setState(() => _isSpeaking = false); };
    _tts.onError = (msg) {
      if (!mounted) return;
      setState(() { _isSpeaking = false; _isLoading = false; });
      _showSnack(msg, isError: true);
    };
    _initTts();
  }

  @override
  void didUpdateWidget(TextScreen old) {
    super.didUpdateWidget(old);
    if (old.settings != widget.settings) {
      _velocidad = widget.settings.velocidad;
      _volumen = widget.settings.volumen;
    }
  }

  Future<void> _initTts() async {
    setState(() => _isLoading = true);
    await _tts.init();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _speak() async {
    final text = _controller.text.trim();
    if (text.isEmpty) { _showSnack('Escribe algo primero'); return; }
    if (_isSpeaking) {
      await _tts.stop();
      setState(() => _isSpeaking = false);
      return;
    }
    setState(() => _isSpeaking = true);
    await _tts.speak(
      text: text,
      settings: widget.settings.copyWith(velocidad: _velocidad, volumen: _volumen),
      userToken: widget.user?.token,
      hasVoice: widget.user?.hasVoice ?? false,
      emocion: _emocion,
    );
  }

  Future<void> _compartir() async {
    final text = _controller.text.trim();
    if (text.isEmpty) { _showSnack('Escribe algo primero'); return; }
    if (widget.user?.token == null || !(widget.user?.hasVoice ?? false)) {
      _showSnack('Necesitas tener una voz clonada para compartir audio', isError: true);
      return;
    }
    if (_isSharing || _isSpeaking) return;

    setState(() => _isSharing = true);
    try {
      final api = VoiceApiService();
      final bytes = await api.synthesize(
        token: widget.user!.token,
        text: text,
        speed: (_velocidad + 0.5).clamp(0.5, 2.0),
      );
      final dir = await getTemporaryDirectory();
      final cleaned = text
          .replaceAll(RegExp(r'[^\w\s]'), '')
          .trim()
          .replaceAll(' ', '_');
      final safeNombre = cleaned.substring(0, cleaned.length.clamp(0, 30));

      final file = File('${dir.path}/voz_$safeNombre.wav');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'audio/wav')],
        text: text,
        subject: 'Audio generado por mi voz',
      );
    } catch (e) {
      if (mounted) _showSnack('Error al generar audio: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? c.warn.withValues(alpha: 0.9) : c.surface,
    ));
  }

  @override
  void dispose() { _tts.dispose(); _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final usingClonedVoice = (widget.user?.hasVoice ?? false) && widget.user != null;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: MainAppBar(
        title: 'Escribir',
        // El estado "usando voz clonada / voz del sistema" ya lo señala
        // el punto rojo sobre el icono VOZ (vozPendiente); se retiró la
        // insignia "Sistema"/"Mi voz" que iba aquí para que esta AppBar
        // sea igual que la del resto de pantallas (solo Voz y Clases).
        vozPendiente: !(widget.user?.hasVoice ?? false),
        onVozTap: widget.onVozTap,
        onClasesTap: widget.onClasesTap,
      ),
      // El body es scrollable para que el teclado no cause overflow
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('Lo que quieres decir'),
            const SizedBox(height: 8),
            Container(
              height: 170,
              decoration: vozCardDecoration(radius: 14),
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: TextStyle(color: c.textPrimary, fontSize: 16, height: 1.5),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(14),
                  hintText: 'Escribe aquí...',
                  hintStyle: TextStyle(color: c.textDim, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _ControlsToggle(
              open: _showControls,
              emocion: _emocion,
              onTap: () => setState(() => _showControls = !_showControls),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _showControls
                  ? _ControlPanel(
                velocidad: _velocidad,
                volumen: _volumen,
                emocion: _emocion,
                showVelocidad: !usingClonedVoice,
                onVelocidadChanged: (v) => setState(() => _velocidad = v),
                onVolumenChanged: (v) => setState(() => _volumen = v),
                onEmocionChanged: (e) => setState(() => _emocion = e),
              )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 32),
            if (_isSpeaking && usingClonedVoice)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 12, height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: c.accent.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Sintetizando con tu voz... puede tardar hasta 60s',
                      style: TextStyle(color: c.textDim, fontSize: 12),
                    ),
                  ],
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SpeakButton(
                  isSpeaking: _isSpeaking,
                  isLoading: _isLoading,
                  onTap: _speak,
                ),
                if (usingClonedVoice) ...[
                  const SizedBox(width: 16),
                  _ShareAudioButton(
                    isSharing: _isSharing,
                    onTap: _compartir,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlsToggle extends StatelessWidget {
  final bool open;
  final VozEmocion emocion;
  final VoidCallback onTap;
  const _ControlsToggle({required this.open, required this.emocion, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AdaptiveColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: vozCardDecoration(radius: 10),
        child: Row(
          children: [
            Icon(Icons.tune_rounded, size: 16, color: c.textMid),
            const SizedBox(width: 8),
            Text('Controles · ${emocion.label}',
                style: TextStyle(color: c.textMid, fontSize: 13)),
            const Spacer(),
            Icon(open ? Icons.expand_less : Icons.expand_more,
                color: c.textDim, size: 18),
          ],
        ),
      ),
    );
  }
}

class _ControlPanel extends StatelessWidget {
  final double velocidad, volumen;
  final VozEmocion emocion;
  final bool showVelocidad;
  final ValueChanged<double> onVelocidadChanged, onVolumenChanged;
  final ValueChanged<VozEmocion> onEmocionChanged;

  const _ControlPanel({
    required this.velocidad, required this.volumen, required this.emocion,
    required this.showVelocidad,
    required this.onVelocidadChanged, required this.onVolumenChanged,
    required this.onEmocionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = AdaptiveColors.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: vozCardDecoration(radius: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showVelocidad) ...[
            _SliderRow(label: 'Velocidad', value: velocidad, onChanged: onVelocidadChanged),
            const SizedBox(height: 4),
          ],
          _SliderRow(label: 'Volumen', value: volumen, onChanged: onVolumenChanged),
          const SizedBox(height: 10),
          Text('Emoción', style: TextStyle(color: c.textMid, fontSize: 12)),
          const SizedBox(height: 6),
          ChipRow(
            options: VozEmocion.values.map((e) => e.label).toList(),
            selected: emocion.label,
            onSelect: (label) {
              final e = VozEmocion.values.firstWhere((e) => e.label == label);
              onEmocionChanged(e);
            },
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  const _SliderRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = AdaptiveColors.of(context);
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(label, style: TextStyle(color: c.textMid, fontSize: 12)),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: 0.1, max: 1.0,
            activeColor: c.accent,
            inactiveColor: c.border,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _ShareAudioButton extends StatelessWidget {
  final bool isSharing;
  final VoidCallback onTap;
  const _ShareAudioButton({required this.isSharing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AdaptiveColors.of(context);
    return GestureDetector(
      onTap: isSharing ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 56, height: 56,
        decoration: BoxDecoration(
          color: isSharing ? c.accent.withValues(alpha: 0.08) : c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSharing ? c.accent.withValues(alpha: 0.5) : c.border,
            width: 1.5,
          ),
        ),
        child: Center(
          child: isSharing
              ? SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: c.accent.withValues(alpha: 0.7),
            ),
          )
              : Icon(Icons.send_rounded, size: 22, color: c.accent),
        ),
      ),
    );
  }
}

