import 'dart:convert';

import 'package:http/http.dart' as http;

/// Why the server last refused something you wrote, for the message on
/// screen. Migrations 020's filter refuses slurs and reserved usernames with
/// `objectionable_content` / `reserved_username`; everything else fails the
/// ordinary way.
///
/// Providers catch errors and return null or false, so the reason is picked
/// up here, where every request passes, instead of being threaded through
/// each of them. [refusalOr] reads it once, and only if it's fresh.
class _Refusal {
  _Refusal(this.message) : at = DateTime.now();
  final String message;
  final DateTime at;
}

_Refusal? _last;

const _messages = {
  'objectionable_content': 'That includes language that isn\'t allowed on '
      '35mm. Please edit it and try again.',
  'reserved_username': 'That username is reserved. Please choose another.',
  'objectionable_image': 'That photo can\'t be used on 35mm. Please choose '
      'another.',
  'image_check_failed': 'Couldn\'t check that photo just now. Please try '
      'again.',
};

/// Records a refusal found outside an HTTP response (the photo check).
void noteRefusal(String code) {
  final message = _messages[code];
  if (message != null) _last = _Refusal(message);
}

/// The refusal's explanation if the server just turned something down for
/// its content, otherwise [fallback].
String refusalOr(String fallback) {
  final r = _last;
  _last = null;
  if (r == null || DateTime.now().difference(r.at).inSeconds > 10) {
    return fallback;
  }
  return r.message;
}

/// Whether [error] is the filter's refusal (for code that has the exception
/// in hand).
bool isContentRefusal(Object error) {
  final text = error.toString();
  return _messages.keys.any(text.contains);
}

/// The message for an exception in hand, or [fallback].
String describeContentError(Object error, String fallback) {
  final text = error.toString();
  for (final e in _messages.entries) {
    if (text.contains(e.key)) return e.value;
  }
  return fallback;
}

/// The HTTP client Supabase uses: passes everything through, and notes a
/// content refusal on the way back.
class RefusalWatchingClient extends http.BaseClient {
  RefusalWatchingClient([http.Client? inner]) : _inner = inner ?? http.Client();

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    // Refusals come back as 400 from PostgREST; nothing else is read.
    if (response.statusCode != 400) return response;
    final bytes = await response.stream.toBytes();
    final body = utf8.decode(bytes, allowMalformed: true);
    for (final e in _messages.entries) {
      if (body.contains(e.key)) _last = _Refusal(e.value);
    }
    return http.StreamedResponse(
      http.ByteStream.fromBytes(bytes),
      response.statusCode,
      contentLength: bytes.length,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() => _inner.close();
}
