import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class OnlineExplanation {
  const OnlineExplanation(this.text, this.citations, this.suggestions);
  final String text;
  final List<Map<String, dynamic>> citations;
  final List<String> suggestions;
}

class OnlineAssistance {
  OnlineAssistance({http.Client? client}) : client = client ?? http.Client();
  final http.Client client;
  Future<OnlineExplanation> request({
    required String endpoint,
    required String token,
    String? description,
    Uint8List? wav,
    required bool consent,
  }) async {
    if (!consent) {
      throw StateError('Confirm sharing before requesting assistance');
    }
    final uri = Uri.tryParse(endpoint.trim());
    if (uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.scheme != 'https' &&
            !(uri.scheme == 'http' &&
                ['localhost', '127.0.0.1', '10.0.2.2'].contains(uri.host)))) {
      throw const FormatException(
        'Use an HTTPS service address, or a local development server',
      );
    }
    if (token.trim().length < 24) {
      throw const FormatException('Enter the configured service token');
    }
    if ((wav == null) == (description == null)) {
      throw const FormatException('Choose audio analysis or text research');
    }
    final target = uri.replace(
      path:
          '${uri.path.replaceFirst(RegExp(r'/$'), '')}/${wav == null ? 'research' : 'analyze'}',
    );
    final response = await client
        .post(
          target,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${token.trim()}',
          },
          body: jsonEncode({
            'consent': true,
            if (wav != null) 'audio': base64Encode(wav),
            'description': ?description,
          }),
        )
        .timeout(const Duration(seconds: 50));
    if (response.statusCode != 200) {
      throw StateError(
        'Assistance unavailable (${response.statusCode}). No sound rule was executed.',
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['kind'] != 'explanation' ||
        json['confirmed'] != false ||
        json['text'] is! String) {
      throw const FormatException('Unsupported assistance response');
    }
    final citations = (json['citations'] as List? ?? [])
        .map((v) => Map<String, dynamic>.from(v as Map))
        .where((v) {
          final link = Uri.tryParse(v['url'].toString());
          return link != null && link.scheme == 'https' && link.host.isNotEmpty;
        })
        .toList();
    return OnlineExplanation(
      json['text'] as String,
      citations,
      (json['searchSuggestions'] as List? ?? []).whereType<String>().toList(),
    );
  }

  void close() => client.close();
}
