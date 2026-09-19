import 'dart:convert';
import 'dart:io';

import 'package:penv/penv.dart';

Future<String> getValidAccessToken() async {
  final env = penvload('.env');

  final refreshToken = env['MEET_REFRESH_TOKEN'];
  final clientId = env['MEET_CLIENT_ID'];
  final clientSecret = env['MEET_CLIENT_SECRET'];

  if (refreshToken == null || clientId == null || clientSecret == null) {
    throw StateError(
      'Missing MEET_REFRESH_TOKEN / MEET_CLIENT_ID / MEET_CLIENT_SECRET '
      'in .env. Run auth.dart once to set these up.',
    );
  }

  final currentAccessToken = env['MEET_ACCESS_TOKEN'];
  final expiryStr = env['MEET_TOKEN_EXPIRY'];
  final expiry = expiryStr != null ? int.tryParse(expiryStr) : null;

  final nowEpoch = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
  final stillValid = currentAccessToken != null &&
      expiry != null &&
      nowEpoch < (expiry - 60);

  if (stillValid) {
    return currentAccessToken;
  }

  return _refreshAccessToken(
    clientId: clientId,
    clientSecret: clientSecret,
    refreshToken: refreshToken,
  );
}

Future<String> _refreshAccessToken({
  required String clientId,
  required String clientSecret,
  required String refreshToken,
}) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(
      Uri.parse('https://oauth2.googleapis.com/token'),
    );
    request.headers.contentType =
        ContentType('application', 'x-www-form-urlencoded');

    final body = Uri(queryParameters: {
      'client_id': clientId,
      'client_secret': clientSecret,
      'refresh_token': refreshToken,
      'grant_type': 'refresh_token',
    },).query;

    request.write(body);

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode != 200) {
      throw Exception('Token refresh failed: ${response.statusCode} $responseBody');
    }

    final tokens = jsonDecode(responseBody) as Map<String, dynamic>;
    final newAccessToken = tokens['access_token'] as String;
    final expiresIn = tokens['expires_in'] as int;

    final newExpiryEpoch =
        DateTime.now().toUtc().add(Duration(seconds: expiresIn)).millisecondsSinceEpoch ~/ 1000;

    _updateEnv({
      'MEET_ACCESS_TOKEN': newAccessToken,
      'MEET_TOKEN_EXPIRY': newExpiryEpoch.toString(),
    });

    return newAccessToken;
  } finally {
    client.close();
  }
}

void _updateEnv(Map<String, String> values) {
  final file = File('.env');
  final existingLines = file.existsSync() ? file.readAsLinesSync() : <String>[];

  final remainingKeys = Map<String, String>.from(values);
  final outputLines = <String>[];

  for (final line in existingLines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#') || !trimmed.contains('=')) {
      outputLines.add(line);
      continue;
    }
    final key = trimmed.substring(0, trimmed.indexOf('=')).trim();
    if (remainingKeys.containsKey(key)) {
      outputLines.add('$key=${remainingKeys.remove(key)}');
    } else {
      outputLines.add(line);
    }
  }

  for (final entry in remainingKeys.entries) {
    outputLines.add('${entry.key}=${entry.value}');
  }

  file.writeAsStringSync(outputLines.join('\n') + '\n');
}
