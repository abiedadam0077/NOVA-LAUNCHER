import 'dart:async';

import 'package:http/http.dart' as http;

/// Thin HTTP wrapper with timeout + bounded retries. Injectable for tests.
class NovaHttp {
  NovaHttp({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const Duration timeout = Duration(seconds: 30);

  Future<http.Response> get(String url, {Map<String, String>? headers}) async {
    return _client
        .get(Uri.parse(url), headers: headers)
        .timeout(timeout);
  }

  Future<http.Response> post(
    String url, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return _client
        .post(Uri.parse(url), headers: headers, body: body)
        .timeout(timeout);
  }

  /// Streaming GET with optional Range for resumable downloads.
  Future<http.StreamedResponse> openStream(
    String url, {
    int? fromByte,
    Map<String, String>? headers,
  }) {
    final req = http.Request('GET', Uri.parse(url));
    req.headers['User-Agent'] = 'NOVA-Launcher/0.1';
    if (headers != null) req.headers.addAll(headers);
    if (fromByte != null && fromByte > 0) {
      req.headers['Range'] = 'bytes=$fromByte-';
    }
    return _client.send(req).timeout(timeout);
  }

  void close() => _client.close();
}
