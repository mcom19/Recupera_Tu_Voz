import "package:flutter/material.dart";
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import "../models/app_user.dart";
import '../models/app_settings.dart';
import '../models/frase_item.dart';
import '../services/settings_service.dart';
import '../services/tts_service.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class FrasesScreen extends StatefulWidget {
  final AppSettings settings;
  final AppUser? user;
  const FrasesScreen({super.key, required this.settings, this.user});

  @override
  State<FrasesScreen> createState() => _FrasesScreenState();
}

class _FrasesScreenState extends State<FrasesScreen> {
  AdaptiveColors get c => AdaptiveColors.of(context);

  late final TtsService _tts;
  final SettingsService _settingsSvc = SettingsService();

  String _categoriaActiva = 'Todas';

  List<FraseItem> _frasesDefault = [];
  List<FraseItem> _frasesPersonales = [];

  bool _loadingDefault = true;

  int? _activeIndex;
  int? _sharingIndex;

  @override
  void initState() {
    super.initState();

    _tts = TtsService();

    _tts.onError = (msg) {
      if (mounted) {
        setState(() => _activeIndex = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: c.warn.withValues(alpha: 0.9),
          ),
        );
      }
    };

    _tts.onDone = () {
      if (mounted) setState(() => _activeIndex = null);
    };

    _tts.init();
    _loadFrases();
  }

  Future<void> _loadFrases() async {
    final api = FrasesApiService();

    final cached = await _settingsSvc.loadCachedFrasesDefault();
    final personales = await _settingsSvc.loadFrasesPersonales();

    if (mounted && cached.isNotEmpty) {
      setState(() {
        _frasesDefault = cached;
        _frasesPersonales = personales;
        _loadingDefault = false;
      });
    }

    try {
      final defaults = await api.fetchDefault();

      if (mounted) {
        setState(() {
          _frasesDefault = defaults.cast<FraseItem>();
          _frasesPersonales = personales;
          _loadingDefault = false;
        });
      }

      await _settingsSvc.saveCachedFrasesDefault(defaults.cast<FraseItem>());

    } catch (_) {
      if (mounted && cached.isEmpty) {
        setState(() => _loadingDefault = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error cargando frases. Modo offline'),
            action: SnackBarAction(
              label: 'Reintentar',
              onPressed: _loadFrases,
            ),
          ),
        );
      }
    }
  }

  List<FraseItem> get _frasesVisibles {
    final todas = [..._frasesDefault, ..._frasesPersonales];

    if (_categoriaActiva == 'Todas') return todas;
    if (_categoriaActiva == 'Mis frases') return _frasesPersonales;

    return todas.where((f) => f.categoria == _categoriaActiva).toList();
  }

  Future<void> _compartirAudio(int index, String texto) async {
    if (widget.user?.token == null || !(widget.user?.hasVoice ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Necesitas tener una voz clonada'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_sharingIndex != null) return;

    setState(() => _sharingIndex = index);

    try {
      final api = VoiceApiService();

      final bytes = await api.synthesize(
        token: widget.user!.token,
        text: texto,
        speed: (widget.settings.velocidad + 0.5).clamp(0.5, 2.0),
      );

      final dir = await getTemporaryDirectory();

      final safeNombreRaw = texto
          .replaceAll(RegExp(r'[^\w\s]'), '')
          .trim()
          .replaceAll(' ', '_');
      final safeNombre = safeNombreRaw.substring(0, safeNombreRaw.length.clamp(0, 30));

      final file = File('${dir.path}/voz_$safeNombre.mp3');

      await file.writeAsBytes(bytes);

      if (!mounted) return;

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'audio/mpeg')],
        text: texto,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharingIndex = null);
    }
  }

  Future<void> _hablar(int index, String texto) async {
    if (_activeIndex != null) return;

    setState(() => _activeIndex = index);

    final ok = await _tts.speak(
      text: texto,
      settings: widget.settings,
      userToken: widget.user?.token,
      hasVoice: widget.user?.hasVoice ?? false,
      userId: widget.user?.userId,
    );

    if (!ok && mounted) setState(() => _activeIndex = null);
  }

  void _mostrarDialogoAdd() {
    final controller = TextEditingController();
    String catSel = 'Mis frases';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38, height: 4,
                    decoration: BoxDecoration(
                      color: c.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text('Nueva frase',
                    style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                AccentTextField(
                  controller: controller,
                  hint: 'Escribe la frase...',
                  maxLines: 3,
                ),
                const SizedBox(height: 14),
                const SectionLabel('Categoría',
                    padding: EdgeInsets.only(bottom: 10)),
                ChipRow(
                  options: const [
                    'Mis frases', 'Saludos', 'Necesidades', 'Respuestas', 'Urgente'
                  ],
                  selected: catSel,
                  onSelect: (c) => setModal(() => catSel = c),
                  colorOf: AppColors.catColor,
                ),
                const SizedBox(height: 18),
                PrimaryButton(
                  label: 'Guardar frase',
                  onTap: () {
                    final texto = controller.text.trim();
                    if (texto.isEmpty) return;
                    final nueva = FraseItem(
                        texto: texto, categoria: catSel, esPersonal: true);
                    final updated = [..._frasesPersonales, nueva];
                    setState(() => _frasesPersonales = updated);
                    _settingsSvc.saveFrasesPersonales(updated);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmarEliminar(FraseItem frase) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Eliminar frase', style: TextStyle(color: c.textPrimary)),
        content: Text('"${frase.texto}"', style: TextStyle(color: c.textMid)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: c.textDim)),
          ),
          TextButton(
            onPressed: () {
              final updated =
              _frasesPersonales.where((f) => f != frase).toList();
              setState(() => _frasesPersonales = updated);
              _settingsSvc.saveFrasesPersonales(updated);
              Navigator.pop(context);
            },
            child: Text('Eliminar', style: TextStyle(color: c.warn)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final frases = _frasesVisibles;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: const Text('Frases rápidas')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: ChipRow(
              options: categoriasAll,
              selected: _categoriaActiva,
              onSelect: (c) => setState(() => _categoriaActiva = c),
              colorOf: AppColors.catColor,
            ),
          ),

          Divider(color: c.border, height: 1),

          Expanded(
            child: _loadingDefault
                ? const Center(child: CircularProgressIndicator())
                : frases.isEmpty
                ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_outline,
                      color: c.textDim, size: 44),
                  const SizedBox(height: 12),
                  Text('No hay frases en esta categoría',
                      style: TextStyle(
                          color: c.textDim, fontSize: 14)),
                ],
              ),
            )
                : GridView.builder(
              padding: const EdgeInsets.all(14),
              // Nº de columnas según ancho disponible en vez de fijo a 2,
              // para aprovechar mejor pantallas grandes (tablet).
              gridDelegate:
              const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 260,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                // Un poco más altas que anchas para que quepa letra más
                // grande sin recortar frases largas.
                childAspectRatio: 1.35,
              ),
              itemCount: frases.length,
              itemBuilder: (_, i) {
                final frase = frases[i];
                final isActive = _activeIndex == i;
                final isBusy = _activeIndex != null && !isActive;
                return _FraseTile(
                  frase: frase,
                  isActive: isActive,
                  isBusy: isBusy,
                  isSharing: _sharingIndex == i,
                  onTap: () => _hablar(i, frase.texto),
                  onShare: (widget.user?.hasVoice ?? false)
                      ? () => _compartirAudio(i, frase.texto)
                      : null,
                  onLongPress: frase.esPersonal
                      ? () => _confirmarEliminar(frase)
                      : null,
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarDialogoAdd,
        backgroundColor: c.accent,
        foregroundColor: c.bg,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }
}

// ── Frase tile ────────────────────────────────────────────────────
class _FraseTile extends StatefulWidget {
  final FraseItem frase;
  final bool isActive;
  final bool isBusy;
  final bool isSharing;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onShare;

  const _FraseTile({
    required this.frase,
    required this.isActive,
    required this.isBusy,
    required this.isSharing,
    required this.onTap,
    this.onLongPress,
    this.onShare,
  });

  @override
  State<_FraseTile> createState() => _FraseTileState();
}

class _FraseTileState extends State<_FraseTile>
    with SingleTickerProviderStateMixin {
  AdaptiveColors get c => AdaptiveColors.of(context);

  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      lowerBound: 0.0,
      upperBound: 0.06,
    );
    _scale = Tween(begin: 1.0, end: 0.93).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _accent => AppColors.catColor(widget.frase.categoria);

  @override
  Widget build(BuildContext context) {
    final opacity = widget.isBusy ? 0.4 : 1.0;

    return AnimatedOpacity(
      opacity: opacity,
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTapDown: widget.isBusy ? null : (_) => _ctrl.forward(),
        onTapUp: widget.isBusy
            ? null
            : (_) {
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: widget.isBusy ? null : () => _ctrl.reverse(),
        onLongPress: widget.isBusy ? null : widget.onLongPress,
        child: ScaleTransition(
          scale: _scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: widget.isActive
                  ? _accent.withValues(alpha: 0.15)
                  : c.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.isActive
                    ? _accent.withValues(alpha: 0.8)
                    : _accent.withValues(alpha: 0.3),
                width: widget.isActive ? 1.5 : 1,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 0, top: 8, bottom: 8,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: _accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (widget.onShare != null)
                  Positioned(
                    top: 5, left: 7,
                    child: GestureDetector(
                      onTap: widget.isBusy || widget.isSharing
                          ? null
                          : widget.onShare,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: widget.isSharing
                            ? SizedBox(
                          width: 12, height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: _accent.withValues(alpha: 0.7),
                          ),
                        )
                            : Icon(
                          Icons.send_rounded,
                          size: 13,
                          color: _accent.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                  ),
                if (widget.isActive)
                  Positioned(
                    top: 8, right: 8,
                    child: SizedBox(
                      width: 12, height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: _accent,
                      ),
                    ),
                  )
                else if (widget.frase.esPersonal)
                  Positioned(
                    top: 8, right: 8,
                    child: Icon(Icons.star_rounded,
                        size: 12, color: _accent.withValues(alpha: 0.6)),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
                  child: Center(
                    child: AutoSizeCardText(
                      widget.frase.texto,
                      maxLines: 4,
                      minFontSize: 13,
                      maxFontSize: 20,
                      style: TextStyle(
                        color: c.textPrimary,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}