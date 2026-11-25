import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Minimal HMAC-signed bearer tokens (header.payload.signature style, 12h expiry).
/// Demo-grade: use a vetted JWT library and hashed passwords in production.
class Auth {
  Auth(this.secret, this.adminUser, this.adminPass);
  final String secret, adminUser, adminPass;

  String? login(String user, String pass) {
    if (user != adminUser || pass != adminPass) return null;
    final exp = DateTime.now().add(const Duration(hours: 12)).millisecondsSinceEpoch ~/ 1000;
    final body = base64Url.encode(utf8.encode(jsonEncode({'sub': user, 'exp': exp})));
    return '$body.${_sign(body)}';
  }

  bool verify(String? header) {
    if (header == null || !header.startsWith('Bearer ')) return false;
    final parts = header.substring(7).split('.');
    if (parts.length != 2 || _sign(parts[0]) != parts[1]) return false;
    final claims = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[0])))) as Map;
    return (claims['exp'] as int) > DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }

  String _sign(String body) => base64Url.encode(Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(body)).bytes);
}
