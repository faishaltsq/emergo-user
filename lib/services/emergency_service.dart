import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:emergo/models/emergency_event.dart';
import 'package:emergo/services/location_service.dart';
import 'package:emergo/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmergencyService {
  static String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? '';
  static String get apiKey => dotenv.env['API_KEY'] ?? '';

  // Optional image URL per type from env, e.g. EMERGENCY_IMAGE_MEDICAL, etc.
  static String? imageUrlForType(EmergencyType type) {
    switch (type) {
      case EmergencyType.medical:
        return dotenv.env['EMERGENCY_IMAGE_MEDICAL'];
      case EmergencyType.fire:
        return dotenv.env['EMERGENCY_IMAGE_FIRE'];
      case EmergencyType.crime:
        return dotenv.env['EMERGENCY_IMAGE_CRIME'];
      case EmergencyType.disaster:
        return dotenv.env['EMERGENCY_IMAGE_DISASTER'];
    }
  }

  static Future<bool> sendEmergencyAlert({
    required EmergencyType type,
    String? additionalInfo,
    String? imageUrl,
    String? imageBase64,
  }) async {
    try {
      // Get current location
      final position = await LocationService.getCurrentPosition();
      final address = await LocationService.getCurrentAddress();

      // Create emergency event
      final emergency = EmergencyEvent(
        id: DateTime.now().millisecondsSinceEpoch,
        type: type,
        dateTime: DateTime.now(),
        status: EmergencyStatus.pending,
      );

      // Save to local storage
      await _saveEmergencyToLocal(emergency);

      // Send to API (if available)
      if (apiBaseUrl.isNotEmpty && apiKey.isNotEmpty) {
        await _sendToAPI(
          emergency,
          position,
          address,
          additionalInfo,
          imageUrl ?? imageUrlForType(type),
          imageBase64,
        );
      }

      // Send notification
      await NotificationService.showEmergencyNotification(
        title: 'Emergency Alert Sent',
        body: 'Your ${type.name} emergency alert has been sent successfully.',
      );

      return true;
    } catch (e) {
      print('Error sending emergency alert: $e');
      return false;
    }
  }

  static Future<void> _sendToAPI(
    EmergencyEvent emergency,
    position,
    String address,
    String? additionalInfo,
    String? imageUrl,
    String? imageBase64,
  ) async {
    try {
      final url = Uri.parse('$apiBaseUrl/emergency');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      };

      final body = json.encode({
        'id': emergency.id,
        'type': emergency.type.name,
        'timestamp': emergency.dateTime.toIso8601String(),
        // include raw coordinates fields as well for convenience
        'latitude': position?.latitude,
        'longitude': position?.longitude,
        'location': {
          'latitude': position?.latitude,
          'longitude': position?.longitude,
          'address': address,
        },
        'additionalInfo': additionalInfo,
        'image': imageUrl, // optional image URL
        'imageBase64': imageBase64, // optional inlined image
        'status': emergency.status.name,
      });

      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        print('Failed to send to API: ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending to API: $e');
    }
  }

  static Future<void> _saveEmergencyToLocal(EmergencyEvent emergency) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final emergencies = await getEmergencyHistory();
      emergencies.add(emergency);

      final emergencyData = emergencies
          .map((e) => {
                'id': e.id,
                'type': e.type.name,
                'dateTime': e.dateTime.toIso8601String(),
                'status': e.status.name,
              })
          .toList();

      await prefs.setString('emergency_history', json.encode(emergencyData));
    } catch (e) {
      print('Error saving emergency to local: $e');
    }
  }

  static Future<List<EmergencyEvent>> getEmergencyHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString('emergency_history');

      if (historyJson == null) {
        // Return sample data if no history exists
        return [
          EmergencyEvent(
            id: 1,
            type: EmergencyType.medical,
            dateTime: DateTime(2024, 1, 15, 14, 30),
            status: EmergencyStatus.handled,
          ),
          EmergencyEvent(
            id: 2,
            type: EmergencyType.fire,
            dateTime: DateTime(2024, 1, 10, 9, 15),
            status: EmergencyStatus.handled,
          ),
          EmergencyEvent(
            id: 3,
            type: EmergencyType.crime,
            dateTime: DateTime(2024, 1, 5, 22, 45),
            status: EmergencyStatus.pending,
          ),
        ];
      }

      final List<dynamic> historyData = json.decode(historyJson);

      return historyData.map((data) {
        return EmergencyEvent(
          id: data['id'],
          type: EmergencyType.values.firstWhere(
            (e) => e.name == data['type'],
            orElse: () => EmergencyType.medical,
          ),
          dateTime: DateTime.parse(data['dateTime']),
          status: EmergencyStatus.values.firstWhere(
            (e) => e.name == data['status'],
            orElse: () => EmergencyStatus.pending,
          ),
        );
      }).toList();
    } catch (e) {
      print('Error getting emergency history: $e');
      return [];
    }
  }

  static Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('emergency_history');
    } catch (e) {
      print('Error clearing history: $e');
    }
  }
}
