import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/main_app_bar.dart';
import 'record_voice_screen.dart';

class CloneVoiceScreen extends StatefulWidget {
  final String token;
  final bool alreadyHasVoice;
  final int initialNumReferences;

  final Future<int> Function(List<({Uint8List bytes, String filename})> files)
  onUploadAdd;

  final Future<int> Function(List<({Uint8List bytes, String filename})> files)
  onUploadReplace;

  final Future<void> Function() onDelete;
  final VoidCallback onDone;
  final VoidCallback? onGoToClases;

  const CloneVoiceScreen({
    super.key,
    required this.token,
    required this.alreadyHasVoice,
    this.initialNumReferences = 0,
    required this.onUploadAdd,
    required this.onUploadReplace,
    required this.onDelete,
    required this.onDone,
    this.onGoToClases,
  });

  @override
  State<CloneVoiceScreen> createState() => _CloneVoiceScreenState();
}

class _CloneVoiceScreenState extends State<CloneVoiceScreen> {
  AdaptiveColors get c => AdaptiveColors.of(context);

  late bool _hasVoice;
  late int _numRefs;
  bool _uploading = false;
  bool _showRecorder = false;
  String? _error;
  String? _success;

  static const int _maxRefs = 3;

  @override
  void initState() {
    super.initState();
    _hasVoice = widget.alreadyHasVoice;
    _numRefs = widget.initialNumReferences;
  }

  Future<void> _pickAndUpload({required bool replace}) async {
    final slots = replace ? _maxRefs : _maxRefs - _numRefs;
    if (slots <= 0) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wav', 'mp3', 'm4a', 'ogg'],
      withData: true,
      allowMultiple: slots > 1,
    );
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.take(slots).toList();
    final filesData = picked
        .where((f) => f.bytes != null)
        .map((f) => (bytes: f.bytes!, filename: f.name))
        .toList();

    if (filesData.isEmpty) return;

    setState(() { _uploading = true; _error = null; _success = null; });

    try {
      final total = replace
          ? await widget.onUploadReplace(filesData)
          : await widget.onUploadAdd(filesData);

      setState(() {
        _hasVoice = true;
        _numRefs = total;
        _success =
        '✅ $_numRefs/$_maxRefs audio${_numRefs == 1 ? '' : 's'} guardado${_numRefs == 1 ? '' : 's'}.'
            '${_numRefs < _maxRefs ? ' Puedes añadir más para mejorar la clonación.' : ' ¡Calidad máxima!'}';
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Eliminar voz', style: TextStyle(color: c.textPrimary)),
        content: Text('¿Seguro que quieres eliminar tu voz clonada?',
            style: TextStyle(color: c.textMid)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancelar', style: TextStyle(color: c.textDim))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Eliminar', style: TextStyle(color: c.warn))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.onDelete();
      setState(() { _hasVoice = false; _numRefs = 0; _success = 'Voz eliminada'; });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showRecorder) {
      return RecordVoiceScreen(
        currentRefs: _numRefs,
        maxRefs: _maxRefs,
        onDone: () => setState(() => _showRecorder = false),
        onRecorded: (files, {required bool replace}) async {
          final total = replace
              ? await widget.onUploadReplace(files)
              : await widget.onUploadAdd(files);
          setState(() {
            _hasVoice = true;
            _numRefs = total;
            _showRecorder = false;
            _success =
            '✅ $_numRefs/$_maxRefs audio${_numRefs == 1 ? '' : 's'} guardado${_numRefs == 1 ? '' : 's'}.'
                '${_numRefs < _maxRefs ? ' Puedes añadir más para mejorar la clonación.' : ' ¡Calidad máxima!'}';
          });
        },
      );
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: MainAppBar(
        title: 'Mi voz clonada',
        showVozAction: false, // ya estamos en esta pantalla
        showClasesAction: widget.onGoToClases != null,
        onClasesTap: widget.onGoToClases,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: widget.onDone,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (_hasVoice ? c.teal : c.accent).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: (_hasVoice ? c.teal : c.accent).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _hasVoice ? Icons.check_circle_outline : Icons.mic_none_rounded,
                    color: _hasVoice ? c.teal : c.accent,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _hasVoice
                              ? 'Tienes una voz clonada activa.'
                              : 'No tienes voz clonada aún.',
                          style: TextStyle(
                            color: _hasVoice ? c.teal : c.accent,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_hasVoice) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: List.generate(_maxRefs, (i) {
                              final filled = i < _numRefs;
                              return Expanded(
                                child: Container(
                                  margin: EdgeInsets.only(right: i < _maxRefs - 1 ? 4 : 0),
                                  height: 6,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(3),
                                    color: filled
                                        ? c.teal
                                        : c.teal.withValues(alpha: 0.2),
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$_numRefs/$_maxRefs muestras  •  '
                                '${_numRefs < _maxRefs ? 'Añade más para mejor calidad' : '¡Calidad máxima!'}',
                            style: TextStyle(
                              color: c.teal.withValues(alpha: 0.8),
                              fontSize: 11,
                            ),
                          ),
                        ] else
                          Text(
                            'Graba o sube hasta 3 audios para empezar.',
                            style: TextStyle(color: c.textDim, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            Text('Instrucciones',
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Text(
              '• Graba desde la app o sube un fichero de audio\n'
                  '• Duración ideal por audio: 30 seg — 2 min\n'
                  '• Sin música ni ruido de fondo\n'
                  '• Formatos al subir: WAV, MP3, M4A, OGG (máx. 20MB c/u)',
              style: TextStyle(color: c.textMid, fontSize: 13, height: 1.8),
            ),
            const SizedBox(height: 28),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(_error!, style: TextStyle(color: c.warn, fontSize: 13)),
              ),
            if (_success != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(_success!, style: TextStyle(color: c.teal, fontSize: 13)),
              ),

            _BigButton(
              label: 'Grabar mi voz ahora',
              icon: Icons.mic_rounded,
              color: c.teal,
              loading: false,
              onTap: () => setState(() {
                _showRecorder = true;
                _error = null;
                _success = null;
              }),
            ),
            const SizedBox(height: 12),

            _BigButton(
              label: _hasVoice
                  ? 'Reemplazar todo (subir fichero)'
                  : 'Seleccionar fichero de audio',
              icon: Icons.upload_file_rounded,
              color: c.accent,
              loading: _uploading,
              onTap: () => _pickAndUpload(replace: true),
              outline: _hasVoice,
            ),

            if (_hasVoice && _numRefs < _maxRefs) ...[
              const SizedBox(height: 12),
              _BigButton(
                label: 'Añadir más audios '
                    '(${_maxRefs - _numRefs} libre${_maxRefs - _numRefs == 1 ? '' : 's'})',
                icon: Icons.add_circle_outline_rounded,
                color: c.accent,
                loading: _uploading,
                onTap: () => _pickAndUpload(replace: false),
                outline: true,
              ),
            ],

            if (_hasVoice) ...[
              const SizedBox(height: 12),
              _BigButton(
                label: 'Eliminar voz clonada',
                icon: Icons.delete_outline_rounded,
                color: c.warn,
                loading: false,
                onTap: _delete,
                outline: true,
              ),
            ],

            const SizedBox(height: 16),
            if (_hasVoice)
              Center(
                child: TextButton(
                  onPressed: widget.onDone,
                  child: Text('← Volver a la app',
                      style: TextStyle(color: c.accent, fontSize: 15)),
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool loading;
  final bool outline;
  final VoidCallback onTap;

  const _BigButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.loading,
    required this.onTap,
    this.outline = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: outline ? Colors.transparent : color,
          borderRadius: BorderRadius.circular(12),
          border: outline ? Border.all(color: color.withValues(alpha: 0.5)) : null,
        ),
        child: Center(
          child: loading
              ? const SizedBox(
              width: 22, height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
              : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: outline ? color : Colors.white, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                      color: outline ? color : Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}