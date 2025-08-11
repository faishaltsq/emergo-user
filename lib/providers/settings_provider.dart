import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const _keyShakeToSOS = 'shake_to_sos_enabled';
  static const _keySilentMode = 'silent_sos_mode';
  static const _keyNotifications = 'notifications_enabled';

  bool _initialized = false;
  bool _shakeToSOSEnabled = true; // default on
  bool _silentMode = false;
  bool _notificationsEnabled = true;

  bool get isInitialized => _initialized;
  bool get shakeToSOSEnabled => _shakeToSOSEnabled;
  bool get silentMode => _silentMode;
  bool get notificationsEnabled => _notificationsEnabled;

  Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _shakeToSOSEnabled = prefs.getBool(_keyShakeToSOS) ?? _shakeToSOSEnabled;
    _silentMode = prefs.getBool(_keySilentMode) ?? _silentMode;
    _notificationsEnabled =
        prefs.getBool(_keyNotifications) ?? _notificationsEnabled;
    _initialized = true;
    notifyListeners();
  }

  Future<void> setShakeToSOSEnabled(bool value) async {
    _shakeToSOSEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShakeToSOS, value);
    notifyListeners();
  }

  Future<void> setSilentMode(bool value) async {
    _silentMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySilentMode, value);
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotifications, value);
    notifyListeners();
  }
}
