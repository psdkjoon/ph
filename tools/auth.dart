// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:penv/penv.dart';

final envFile = penvload('.env');

final clientId = envFile['MEET_CLIENT_ID'];
final clientSecret = envFile['MEET_CLIENT_SECRET'];

const scopes = 'https://www.googleapis.com/auth/meetings.space.created';
const redirectPort = 8080;
const redirectUri = 'http://localhost:$redirectPort';

const envPath = '.env';

Future<void> main() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, redirectPort);
  print('Listening on $redirectUri for the OAuth redirect...');

  final authUri = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
    'client_id': clientId,
    'redirect_uri': redirectUri,
    'response_type': 'code',
    'scope': scopes,
    'access_type': 'offline',
    'prompt': 'consent',
  });

  print('\nOpen this URL in your browser and log in:\n');
  print(authUri.toString());
  print('\nWaiting for you to authorize...\n');

  final request = await server.first;
  final code = request.uri.queryParameters['code'];
  final error = request.uri.queryParameters['error'];

  request.response.headers.contentType = ContentType.html;
  if (code != null) {
    request.response.write('<h2>Success! You can close this tab.</h2>');
  } else {
    request.response.write('<h2>Authorization failed: $error</h2>');
  }
  await request.response.close();
  await server.close();

  if (code == null) {
    stderr.writeln('Authorization failed: $error');
    exit(1);
  }

  final client = HttpClient();
  try {
    final tokenRequest = await client.postUrl(
      Uri.parse('https://oauth2.googleapis.com/token'),
    );
    tokenRequest.headers.contentType =
        ContentType('application', 'x-www-form-urlencoded');

    final body = Uri(queryParameters: {
      'client_id': clientId,
      'client_secret': clientSecret,
      'code': code,
      'grant_type': 'authorization_code',
      'redirect_uri': redirectUri,
    },).query;

    tokenRequest.write(body);

    final tokenResponse = await tokenRequest.close();
    final tokenBody = await tokenResponse.transform(utf8.decoder).join();

    if (tokenResponse.statusCode != 200) {
      stderr.writeln('Token exchange failed: ${tokenResponse.statusCode} $tokenBody');
      exit(1);
    }

    final tokens = jsonDecode(tokenBody) as Map<String, dynamic>;

    final accessToken = tokens['access_token'] as String;
    final refreshToken = tokens['refresh_token'] as String?;
    final expiresIn = tokens['expires_in'] as int; // seconds

    if (refreshToken == null) {
      stderr.writeln(
        'WARNING: No refresh_token returned. This usually means you\'ve '
        'already granted consent before without revoking it. Go to '
        'https://myaccount.google.com/permissions, remove access for '
        '"psdk-helper", and run this script again.',
      );
      exit(1);
    }

    final expiryEpochSeconds =
        DateTime.now().toUtc().add(Duration(seconds: expiresIn)).millisecondsSinceEpoch ~/ 1000;

    writeEnv({
      'MEET_ACCESS_TOKEN': accessToken,
      'MEET_REFRESH_TOKEN': refreshToken,
      'MEET_TOKEN_EXPIRY': expiryEpochSeconds.toString(),
      'MEET_CLIENT_ID': clientId!,
      'MEET_CLIENT_SECRET': clientSecret!,
    });

    print('Success! Tokens saved to $envPath');
    print('Your bot can now call meet_token.dart to get a fresh access token anytime.');
  } finally {
    client.close();
  }
}

void writeEnv(Map<String, String> values) {
  final file = File(envPath);
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
