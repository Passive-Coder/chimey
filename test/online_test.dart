import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:chimey/sounds/online.dart';

void main() {
  const token = 'service-token-with-at-least-24-characters';
  test(
    'sharing is opt-in and unsafe endpoints are rejected before transport',
    () async {
      var calls = 0;
      final online = OnlineAssistance(
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );
      await expectLater(
        online.request(
          endpoint: 'https://example.com',
          token: token,
          description: 'beep',
          consent: false,
        ),
        throwsStateError,
      );
      await expectLater(
        online.request(
          endpoint: 'http://public.example',
          token: token,
          description: 'beep',
          consent: true,
        ),
        throwsFormatException,
      );
      expect(calls, 0);
      online.close();
    },
  );
  test(
    'only explicitly consented audio is forwarded and explanations remain unconfirmed',
    () async {
      final online = OnlineAssistance(
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(request.url.path, '/assist/analyze');
          expect(request.headers['Authorization'], 'Bearer $token');
          expect(body['consent'], true);
          expect(body['audio'], base64Encode([1, 2, 3]));
          expect(body.containsKey('description'), false);
          return http.Response(
            jsonEncode({
              'kind': 'explanation',
              'confirmed': false,
              'text': 'A possible beep',
              'citations': [
                {'title': 'Unsafe', 'url': 'javascript:alert(1)'},
                {'title': 'Source', 'url': 'https://example.com/manual'},
              ],
            }),
            200,
          );
        }),
      );
      final result = await online.request(
        endpoint: 'https://example.com/assist',
        token: token,
        wav: Uint8List.fromList([1, 2, 3]),
        consent: true,
      );
      expect(result.text, 'A possible beep');
      expect(result.citations.length, 1);
      online.close();
    },
  );
  test('online result cannot masquerade as a personal match', () async {
    final online = OnlineAssistance(
      client: MockClient(
        (_) async => http.Response(
          '{"kind":"personal","confirmed":true,"text":"Laundry finished"}',
          200,
        ),
      ),
    );
    await expectLater(
      online.request(
        endpoint: 'https://example.com',
        token: token,
        description: 'beep',
        consent: true,
      ),
      throwsFormatException,
    );
    online.close();
  });
}
