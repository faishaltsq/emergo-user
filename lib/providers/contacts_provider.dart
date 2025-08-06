import 'package:flutter/foundation.dart';
import 'package:emergo/models/contact.dart';

class ContactsProvider extends ChangeNotifier {
  final List<Contact> _contacts = [
    Contact(id: 1, name: "John Doe", phone: "+1 234 567 8900", autoNotify: true),
    Contact(id: 2, name: "Jane Smith", phone: "+1 234 567 8901", autoNotify: false),
  ];

  List<Contact> get contacts => [..._contacts];

  void addContact(String name, String phone) {
    if (name.isNotEmpty && phone.isNotEmpty) {
      final newContact = Contact(
        id: DateTime.now().millisecondsSinceEpoch,
        name: name,
        phone: phone,
      );
      _contacts.add(newContact);
      notifyListeners();
    }
  }

  void deleteContact(int id) {
    _contacts.removeWhere((contact) => contact.id == id);
    notifyListeners();
  }

  void toggleAutoNotify(int id) {
    final contactIndex = _contacts.indexWhere((contact) => contact.id == id);
    if (contactIndex != -1) {
      _contacts[contactIndex].autoNotify = !_contacts[contactIndex].autoNotify;
      notifyListeners();
    }
  }
}