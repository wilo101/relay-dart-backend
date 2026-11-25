import 'dart:convert';
import 'package:shelf/shelf.dart';

class ValidationError implements Exception {
  ValidationError(this.errors);
  final Map<String, String> errors;
}

/// Reads a JSON object body or throws a ValidationError.
Future<Map<String, dynamic>> readJson(Request r) async {
  try {
    final v = jsonDecode(await r.readAsString());
    if (v is Map<String, dynamic>) return v;
  } catch (_) {}
  throw ValidationError({'body': 'must be a JSON object'});
}

final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

bool isEmail(String s) => _email.hasMatch(s);

bool isHttpUrl(String s) {
  final u = Uri.tryParse(s);
  return u != null && (u.scheme == 'http' || u.scheme == 'https') && u.host.isNotEmpty;
}
