import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class UserProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  // Optional basic profile fields for future use
  String _name = 'John Doe';
  String _phone = '+1 234 567 8900';
  String _email = 'john.doe@email.com';
  String? _accessToken;
  String? _tokenType;

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get error => _error;

  String get name => _name;
  String get phone => _phone;
  String get email => _email;
  String? get accessToken => _accessToken;
  String? get tokenType => _tokenType;
  bool get isInitialized => _isInitialized;

  UserProvider();

  Future<void> initialize() async {
    if (_isInitialized) return;
    await _loadFromStorage();
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
    _tokenType = prefs.getString('token_type');
    _email = prefs.getString('user_email') ?? _email;
    _name = prefs.getString('user_name') ?? _name;
    _phone = prefs.getString('user_phone') ?? _phone;
    _isLoggedIn = _accessToken != null && _accessToken!.isNotEmpty;
  }

  Future<bool> loginWithEmailPassword({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data =
          await AuthService.instance.login(email: email, password: password);
      _accessToken = data['access_token'] as String?;
      _tokenType = data['token_type'] as String?;
      _email = email;
      _isLoggedIn = _accessToken != null && _accessToken!.isNotEmpty;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', _accessToken!);
      await prefs.setString('token_type', _tokenType ?? 'Bearer');
      await prefs.setString('user_email', _email);
      // name/phone may be populated later via profile endpoint

      return true;
    } on AuthException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = 'Unexpected error: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await AuthService.instance.register(
        email: email,
        password: password,
        fullName: fullName,
      );

      _accessToken = data['access_token'] as String?;
      _tokenType = data['token_type'] as String?;
      _email = email;
      _name = fullName;
      _isLoggedIn = _accessToken != null && _accessToken!.isNotEmpty;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', _accessToken!);
      await prefs.setString('token_type', _tokenType ?? 'Bearer');
      await prefs.setString('user_email', _email);
      await prefs.setString('user_name', _name);
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = 'Unexpected error: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void logout() {
    _isLoggedIn = false;
    _accessToken = null;
    _tokenType = null;
    _error = null;
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('access_token');
      prefs.remove('token_type');
    });
    notifyListeners();
  }

  void updateProfile({String? name, String? phone, String? email}) {
    if (name != null) _name = name;
    if (phone != null) _phone = phone;
    if (email != null) _email = email;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('user_name', _name);
      prefs.setString('user_phone', _phone);
      prefs.setString('user_email', _email);
    });
    notifyListeners();
  }
}
