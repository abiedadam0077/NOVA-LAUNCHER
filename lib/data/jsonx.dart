import 'dart:convert';

/// Single import point for JSON decoding with typed helpers.
Map<String, dynamic> jsonMap(String body) =>
    jsonDecode(body) as Map<String, dynamic>;

List<dynamic> jsonList(String body) => jsonDecode(body) as List<dynamic>;

String jsonEncodeSafe(Object? o) => jsonEncode(o);
