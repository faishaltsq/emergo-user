import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => 'AuthException: $message';
}

class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  String get _baseUrl {
    final fromEnv = dotenv.env['API_BASE_URL']?.trim();
    var url = (fromEnv == null || fromEnv.isEmpty)
        ? 'http://127.0.0.1:8000'
        : fromEnv;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    return url.replaceAll(RegExp(r'/+$'), '');
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$_baseUrl/auth/login');

    final res = await http.post(
      uri,
      headers: const {
        'accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['access_token'] is String && data['token_type'] is String) {
        return data;
      }
      throw AuthException('Unexpected response from server');
    }

    // Try parse error message if provided
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['detail'] is String) {
        throw AuthException(body['detail'] as String);
      }
    } catch (_) {}

    if (res.statusCode == 401 || res.statusCode == 400) {
      throw AuthException('Invalid email or password');
    }
    throw AuthException('Login failed (code ${res.statusCode})');
  }

  /// Register a new user.
  /// Request body: { email, password, full_name }
  /// Response (200): { "access_token": string, "token_type": string }
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final uri = Uri.parse('$_baseUrl/auth/register'); // Provided by curl example
    final res = await http.post(
      uri,
      headers: const {
        'accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
        'full_name': fullName,
      }),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['access_token'] is String && data['token_type'] is String) {
        return data;
      }
      throw AuthException('Unexpected response from server');
    }

    if (res.statusCode == 422) {
      // Try to extract validation messages
      try {
        final body = jsonDecode(res.body);
        if (body is Map && body['detail'] != null) {
          final detail = body['detail'];
          if (detail is List) {
            final msgs = detail
                .map((e) => e is Map && e['msg'] != null
                    ? (e['loc'] != null ? '${e['msg']} (${e['loc']})' : e['msg'])
                    : e.toString())
                .join('; ');
            throw AuthException('Validation failed: $msgs');
          } else if (detail is String) {
            throw AuthException('Validation failed: $detail');
          }
        }
      } catch (_) {}
      throw AuthException('Validation failed (422)');
    }

    // Try parse generic error message
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['detail'] is String) {
        throw AuthException(body['detail'] as String);
      }
    } catch (_) {}

    throw AuthException('Registration failed (code ${res.statusCode})');
  }
}
