import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class LocationService {
  static String get googleMapsApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  static Future<bool> requestLocationPermission() async {
    final status = await Permission.location.request();
    return status == PermissionStatus.granted;
  }

  static Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        throw Exception('Location permission denied');
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return position;
    } catch (e) {
      print('Error getting current position: $e');
      return null;
    }
  }

  static Future<String> getCurrentAddress() async {
    try {
      final position = await getCurrentPosition();
      if (position == null) {
        return 'Unable to get current location';
      }

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return '${place.street}, ${place.locality}, ${place.country}';
      }

      return 'Unknown location';
    } catch (e) {
      print('Error getting current address: $e');
      return 'Unable to get current address';
    }
  }

  static Future<Map<String, dynamic>> getNearbyFacilities({
    required String type,
    double radius = 5000, // 5km
  }) async {
    try {
      final position = await getCurrentPosition();
      if (position == null) {
        throw Exception('Unable to get current location');
      }

      final apiKey = googleMapsApiKey;
      if (apiKey.isEmpty) {
        // Return mock data if no API key
        return _getMockFacilities(type);
      }

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
        '?location=${position.latitude},${position.longitude}'
        '&radius=$radius'
        '&type=$type'
        '&key=$apiKey',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        return _getMockFacilities(type);
      }
    } catch (e) {
      print('Error getting nearby facilities: $e');
      return _getMockFacilities(type);
    }
  }

  static Map<String, dynamic> _getMockFacilities(String type) {
    return {
      'results': [
        {
          'name': 'City General Hospital',
          'type': 'Hospital',
          'distance': '0.8 km',
          'vicinity': 'Downtown District',
          'rating': 4.5,
        },
        {
          'name': 'Downtown Police Station',
          'type': 'Police',
          'distance': '1.2 km',
          'vicinity': 'Main Street',
          'rating': 4.2,
        },
        {
          'name': 'Fire Station #3',
          'type': 'Fire Department',
          'distance': '1.5 km',
          'vicinity': 'Central Avenue',
          'rating': 4.8,
        },
      ],
    };
  }

  static Future<String> getDirectionsUrl({
    required double destLat,
    required double destLng,
  }) async {
    final position = await getCurrentPosition();
    if (position == null) {
      return '';
    }

    return 'https://www.google.com/maps/dir/${position.latitude},${position.longitude}/$destLat,$destLng';
  }
}
