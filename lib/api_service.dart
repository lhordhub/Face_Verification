// api_service.dart
//
// All communication with the Flask server on Render.

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';

class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, this.statusCode);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  static Map<String, String> get _headers => {
        if (AppConfig.apiKey.isNotEmpty) 'X-API-Key': AppConfig.apiKey,
      };

  /// Pings the server. On Render's free plan a sleeping server needs up to
  /// about a minute to wake up, so this waits longer than normal requests.
  static Future<bool> wakeServer() async {
    try {
      final response = await http
          .get(Uri.parse('${AppConfig.baseUrl}/api/health'))
          .timeout(const Duration(seconds: 90));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Uploads the reference photos. Returns the server's JSON, which contains
  /// "reference" (save it on the phone), "num_used" and "skipped".
  static Future<Map<String, dynamic>> register(List<String> photoPaths) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.baseUrl}/api/register'),
    )..headers.addAll(_headers);

    for (final path in photoPaths) {
      request.files.add(await http.MultipartFile.fromPath('photos', path));
    }
    return _send(request, const Duration(seconds: 90));
  }

  /// Checks one frame against the saved reference.
  static Future<Map<String, dynamic>> verify(
    String photoPath,
    Map<String, dynamic> reference,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.baseUrl}/api/verify'),
    )
      ..headers.addAll(_headers)
      ..fields['reference'] = jsonEncode(reference)
      ..files.add(await http.MultipartFile.fromPath('photo', photoPath));

    return _send(request, const Duration(seconds: 30));
  }

  static Future<Map<String, dynamic>> _send(
    http.MultipartRequest request,
    Duration timeout,
  ) async {
    final streamed = await request.send().timeout(timeout);
    final response = await http.Response.fromStream(streamed).timeout(timeout);

    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(
        'Unexpected server response (${response.statusCode}).',
        response.statusCode,
      );
    }

    if (response.statusCode >= 400) {
      throw ApiException(
        (body['error'] ?? 'Request failed (${response.statusCode}).').toString(),
        response.statusCode,
      );
    }
    return body;
  }
}
