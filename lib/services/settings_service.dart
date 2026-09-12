import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../models/frase_item.dart';

class SettingsService {
  static const _keySettings = 'app_settings';
  static const _keyFrases = 'frases_personales';

  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keySettings);
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySettings, jsonEncode(settings.toJson()));
  }

  Future<List<FraseItem>> loadFrasesPersonales() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keyFrases) ?? [];
    return raw
        .map((s) => FraseItem.fromJsonString(s))
        .toList();
  }

  Future<void> saveFrasesPersonales(List<FraseItem> frases) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyFrases,
      frases.map((f) => f.toJsonString()).toList(),
    );
  }
  static const _keyFrasesDefaultCache     = 'frases_default_cache';
  static const _keyFrasesDefaultCacheTime = 'frases_default_cache_time';
  static const _ttlHours = 24;

  Future<List<FraseItem>> loadCachedFrasesDefault() async {
    final prefs = await SharedPreferences.getInstance();

    final savedAt = prefs.getInt(_keyFrasesDefaultCacheTime) ?? 0;
    final age = DateTime.now().millisecondsSinceEpoch - savedAt;
    final expired = age > _ttlHours * 3600 * 1000;
    final raw = prefs.getStringList(_keyFrasesDefaultCache) ?? [];
    if (raw.isEmpty) return [];
    if (expired) return []; // forzar fetch si expiró
    return raw.map((s) => FraseItem.fromJsonString(s)).toList();
  }

  Future<void> saveCachedFrasesDefault(List<FraseItem> frases) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyFrasesDefaultCache,
      frases.map((f) => f.toJsonString()).toList(),
    );
    await prefs.setInt(
      _keyFrasesDefaultCacheTime,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  // ── Bienvenida (pantalla "Inicio") ──────────────────────────────
  // Se muestra solo la primera vez que el paciente entra a la app;
  // a partir de ahí se abre directamente en la pestaña de Texto.
  static const _keySeenWelcome = 'has_seen_welcome';

  Future<bool> hasSeenWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keySeenWelcome) ?? false;
  }

  Future<void> markWelcomeSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySeenWelcome, true);
  }
}
