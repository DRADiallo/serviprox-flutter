// lib/core/controllers/settings_provider.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider global pour le thème et la langue.
/// À enregistrer dans main.dart avec ChangeNotifierProvider.
class SettingsProvider extends ChangeNotifier {
  static const _keyTheme = 'pref_theme'; // 'light' | 'dark' | 'system'
  static const _keyLang  = 'pref_lang';  // 'fr' | 'en' | 'ar'
  static const _keyNotif = 'pref_notif';

  String _themeMode    = 'system';
  String _locale       = 'fr';
  bool   _notifEnabled = true;

  String get themeMode    => _themeMode;
  String get locale       => _locale;
  bool   get notifEnabled => _notifEnabled;

  /// ThemeMode Flutter correspondant au choix enregistré.
  ThemeMode get flutterThemeMode {
    if (_themeMode == 'dark')  return ThemeMode.dark;
    if (_themeMode == 'light') return ThemeMode.light;
    return ThemeMode.system;
  }

  /// Locale Flutter correspondante au choix enregistré.
  Locale get flutterLocale {
    if (_locale == 'en') return const Locale('en', 'US');
    if (_locale == 'ar') return const Locale('ar', 'SA');
    return const Locale('fr', 'FR');
  }

  /// Charger les préférences sauvegardées (appeler dans main() avant runApp).
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _themeMode    = p.getString(_keyTheme) ?? 'system';
    _locale       = p.getString(_keyLang)  ?? 'fr';
    _notifEnabled = p.getBool(_keyNotif)   ?? true;
    notifyListeners();
  }

  // ─── Thème ──────────────────────────────────────────────

  Future<void> setTheme(String mode) async {
    _themeMode = mode;
    notifyListeners();
    (await SharedPreferences.getInstance()).setString(_keyTheme, mode);
  }

  // ─── Langue ─────────────────────────────────────────────

  Future<void> setLocale(String code) async {
    _locale = code;
    notifyListeners();
    (await SharedPreferences.getInstance()).setString(_keyLang, code);
  }

  // ─── Notifications ──────────────────────────────────────

  Future<void> setNotif(bool val) async {
    _notifEnabled = val;
    notifyListeners();
    (await SharedPreferences.getInstance()).setBool(_keyNotif, val);
    // TODO: appeler FirebaseMessaging.instance.requestPermission() / deleteToken()
  }
}