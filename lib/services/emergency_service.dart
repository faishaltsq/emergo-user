import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:emergo/models/emergency_event.dart';
import 'package:emergo/services/location_service.dart';
import 'package:emergo/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/incident.dart';

class EmergencyService {
  // Normalize base URL similar to AuthService
  static String get _baseUrl {
    final fromEnv = dotenv.env['API_BASE_URL']?.trim();
    var url = (fromEnv == null || fromEnv.isEmpty)
        ? 'http://127.0.0.1:8000'
        : fromEnv;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    return url.replaceAll(RegExp(r'/+$'), '');
  }

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
      if (position == null) {
        throw Exception('Unable to get current location');
      }

      // Create emergency event (local history + UX)
      final emergency = EmergencyEvent(
        id: DateTime.now().millisecondsSinceEpoch,
        type: type,
        dateTime: DateTime.now(),
        status: EmergencyStatus.pending,
      );

      // Save to local storage
      await _saveEmergencyToLocal(emergency);

      // Send to backend API using authenticated user token
      await _sendToIncidentsAPI(
        incidentTypeId: _incidentTypeIdFor(type),
        latitude: position.latitude,
        longitude: position.longitude,
      );

      // Local notification confirmation
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

  static Future<void> _sendToIncidentsAPI({
    required int incidentTypeId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final tokenType = prefs.getString('token_type') ?? 'Bearer';
      if (token == null || token.isEmpty) {
        throw Exception('User not authenticated');
      }

      final uri = Uri.parse('$_baseUrl/users/me/incidents');
      final headers = <String, String>{
        'accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': '$tokenType $token',
      };

      final body = jsonEncode({
        'incidenttypeid': incidentTypeId,
        'latitude': latitude,
        'longitude': longitude,
      });

      final res = await http.post(uri, headers: headers, body: body);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        // Try to log server-provided error
        try {
          final parsed = jsonDecode(res.body);
          print('Incident submit failed: ${res.statusCode} - $parsed');
        } catch (_) {
          print('Incident submit failed: ${res.statusCode}');
        }
        throw Exception('Incident API error ${res.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  static int _incidentTypeIdFor(EmergencyType type) {
    switch (type) {
      case EmergencyType.medical:
        return 1; // Darurat Medis
      case EmergencyType.fire:
        return 2; // Kebakaran
      case EmergencyType.crime:
        return 3; // Kriminal
      case EmergencyType.disaster:
        return 4; // Bencana alam
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

  // Remote incidents history for the authenticated user
  static Future<List<Incident>> fetchIncidents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final tokenType = prefs.getString('token_type') ?? 'Bearer';
      if (token == null || token.isEmpty) {
        throw Exception('Unauthenticated');
      }

      final uri = Uri.parse('$_baseUrl/users/me/incidents');
      final res = await http.get(
        uri,
        headers: {
          'accept': 'application/json',
          'Authorization': '$tokenType $token',
        },
      );

      if (res.statusCode == 200) {
        final parsed = jsonDecode(res.body);
        if (parsed is List) {
          return parsed
              .whereType<Map<String, dynamic>>()
              .map((e) => Incident.fromJson(e))
              .toList();
        }
        // If server returns an object, try to unwrap array-like key
        if (parsed is Map && parsed['items'] is List) {
          return (parsed['items'] as List)
              .whereType<Map<String, dynamic>>()
              .map((e) => Incident.fromJson(e))
              .toList();
        }
        throw Exception('Unexpected history response');
      }

      // Try extract server error
      try {
        final body = jsonDecode(res.body);
        throw Exception('History error ${res.statusCode}: $body');
      } catch (_) {
        throw Exception('History error ${res.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Background-safe helper: returns false without doing a network call
  // when unauthenticated or token is empty. Otherwise, checks incidents
  // and returns true if any has statusId != 4 (active/in-progress).
  static Future<bool> hasActiveEmergencyIfAuthenticated() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null || token.isEmpty) {
        // Skip background call entirely if unauthenticated
        return false;
      }
      final incidents = await fetchIncidents();
      return incidents.any((i) => i.statusId != 4);
    } catch (_) {
      // On any error during background check, fail-open (no active)
      return false;
    }
  }
}
