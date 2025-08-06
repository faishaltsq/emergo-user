class Contact {
  final int id;
  final String name;
  final String phone;
  bool autoNotify;

  Contact({
    required this.id,
    required this.name,
    required this.phone,
    this.autoNotify = false,
  });
}