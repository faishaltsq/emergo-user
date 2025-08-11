import 'package:flutter/foundation.dart';

class UserProvider extends ChangeNotifier {
  bool _isLoggedIn = false;

  // Optional basic profile fields for future use
  String _name = 'John Doe';
  String _phone = '+1 234 567 8900';
  String _email = 'john.doe@email.com';

  bool get isLoggedIn => _isLoggedIn;

  String get name => _name;
  String get phone => _phone;
  String get email => _email;

  void login({String? name, String? phone, String? email}) {
    _isLoggedIn = true;
    if (name != null) _name = name;
    if (phone != null) _phone = phone;
    if (email != null) _email = email;
    notifyListeners();
  }

  void logout() {
    _isLoggedIn = false;
    notifyListeners();
  }

  void updateProfile({String? name, String? phone, String? email}) {
    if (name != null) _name = name;
    if (phone != null) _phone = phone;
    if (email != null) _email = email;
    notifyListeners();
  }
}
