import 'package:flutter/material.dart';
import '../../models/app_settings.dart';
import '../../services/settings_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/main_app_bar.dart';
import '../../widgets/voz_menu_card.dart';

/// Ajustes funcionales de la app: tema, idioma, velocidad y volumen de
/// voz. Son los que se tocan con más frecuencia dentro de "Ajustes".
class AjustesFuncionalesScreen extends StatefulWidget {
  final AppSettings settings;
  final ValueChanged<AppSettings> onSettingsChanged;
  final bool hasVoice;
  final VoidCallback onGoToVoz;
  final VoidCallback onGoToClases;

  const AjustesFuncionalesScreen({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
    required this.hasVoice,
    required this.onGoToVoz,
    required this.onGoToClases,
  });

  @override
  State<AjustesFuncionalesScreen> createState() => _AjustesFuncionalesScreenState();
}

class _AjustesFuncionalesScreenState extends State<AjustesFuncionalesScreen> {
  AdaptiveColors get c => AdaptiveColors.of(context);

  late AppSettings _settings;
  final SettingsService _svc = SettingsService();

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  void _update(AppSettings s) {
    setState(() => _settings = s);
    _svc.saveSettings(s);
    widget.onSettingsChanged(s);
  }

  void _showLanguageDialog() {
    const idiomas = ['Español', 'English', 'Français', 'Deutsch', 'Italiano'];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Idioma', style: TextStyle(color: c.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: idiomas
              .map((lang) => RadioListTile<String>(
                    value: lang,
                    groupValue: _settings.idioma,
                    activeColor: c.accent,
                    title: Text(lang, style: TextStyle(color: c.textPrimary, fontSize: 14)),
                    onChanged: (v) {
                      _update(_settings.copyWith(idioma: v));
                      Navigator.pop(context);
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: c.bg,
      appBar: MainAppBar(
        title: 'Ajustes',
        vozPendiente: !widget.hasVoice,
        onVozTap: widget.onGoToVoz,
        onClasesTap: widget.onGoToClases,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: vozCardDecoration(radius: 10),
            child: Row(
              children: [
                Icon(
                  _settings.temaOscuro ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  size: 18,
                  color: _settings.temaOscuro ? c.textMid : c.gold,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _settings.temaOscuro ? 'Tema oscuro' : 'Tema claro',
                    style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
                Switch(
                  value: !_settings.temaOscuro,
                  onChanged: (claro) => _update(_settings.copyWith(temaOscuro: !claro)),
                ),
              ],
            ),
          ),
          _Tile(
            label: 'Idioma',
            value: _settings.idioma,
            onTap: _showLanguageDialog,
          ),
          const SizedBox(height: 6),
          _SliderTile(
            label: 'Velocidad de voz',
            value: _settings.velocidad,
            min: 0.1,
            max: 1.0,
            onChanged: (v) => _update(_settings.copyWith(velocidad: v)),
          ),
          const SizedBox(height: 6),
          _SliderTile(
            label: 'Volumen',
            value: _settings.volumen,
            min: 0.1,
            max: 1.0,
            onChanged: (v) => _update(_settings.copyWith(volumen: v)),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback? onTap;
  const _Tile({required this.label, this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AdaptiveColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: vozCardDecoration(radius: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                  if (value != null)
                    Text(value!, style: TextStyle(color: c.textMid, fontSize: 12)),
                ],
              ),
            ),
            if (onTap != null) Icon(Icons.chevron_right, color: c.textDim, size: 18),
          ],
        ),
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  final String label;
  final double value, min, max;
  final ValueChanged<double> onChanged;
  const _SliderTile({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = AdaptiveColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      decoration: vozCardDecoration(radius: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
          Slider(
            value: value,
            min: min,
            max: max,
            activeColor: c.accent,
            inactiveColor: c.border,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
