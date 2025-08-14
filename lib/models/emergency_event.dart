import 'package:flutter/material.dart';

enum EmergencyType {
  medical,
  fire,
  crime,
  disaster,
}

enum EmergencyStatus {
  pending,
  enroute,
  solved,
  denied,
}

class EmergencyEvent {
  final int id;
  final EmergencyType type;
  final DateTime dateTime;
  final EmergencyStatus status;

  EmergencyEvent({
    required this.id,
    required this.type,
    required this.dateTime,
    required this.status,
  });

  IconData get icon {
    switch (type) {
      case EmergencyType.medical:
        return Icons.favorite;
      case EmergencyType.fire:
        return Icons.local_fire_department;
      case EmergencyType.crime:
        return Icons.shield;
      case EmergencyType.disaster:
        return Icons.warning;
    }
  }

  String get typeName {
    switch (type) {
      case EmergencyType.medical:
        return 'Medical';
      case EmergencyType.fire:
        return 'Fire';
      case EmergencyType.crime:
        return 'Crime';
      case EmergencyType.disaster:
        return 'Disaster';
    }
  }
}
