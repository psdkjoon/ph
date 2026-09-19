import 'dart:convert';
import 'dart:io';

import 'meet_token.dart';

Future<String> createGoogleMeet() async {
  final client = HttpClient();

  final accessToken = await getValidAccessToken();

  try {
    final createRequest = await client.postUrl(
      Uri.parse('https://meet.googleapis.com/v2/spaces'),
    );

    createRequest.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer $accessToken',
    );
    createRequest.headers.contentType = ContentType.json;
    createRequest.write('{}');

    final createResponse = await createRequest.close();
    final createBody = await createResponse.transform(utf8.decoder).join();

    if (createResponse.statusCode != 200) {
      throw Exception(
        'Create meeting failed: '
        '${createResponse.statusCode} $createBody',
      );
    }

    final space = jsonDecode(createBody) as Map<String, dynamic>;

    final spaceName = space['name'] as String;
    final meetingUri = space['meetingUri'] as String;

    final updateRequest = await client.patchUrl(
      Uri.parse(
        'https://meet.googleapis.com/v2/$spaceName'
        '?updateMask=config.accessType,config.entryPointAccess',
      ),
    );

    updateRequest.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer $accessToken',
    );
    updateRequest.headers.contentType = ContentType.json;

    updateRequest.write(
      jsonEncode({
        'config': {
          'accessType': 'OPEN',
          'entryPointAccess': 'ALL',
        },
      }),
    );

    final updateResponse = await updateRequest.close();
    final updateBody = await updateResponse.transform(utf8.decoder).join();

    if (updateResponse.statusCode != 200) {
      throw Exception(
        'Configure meeting failed: '
        '${updateResponse.statusCode} $updateBody',
      );
    }

    return meetingUri;
  } finally {
    client.close();
  }
}
