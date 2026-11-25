import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'models/user.dart';

/// Claims carried by a verified token.
class Claims {
  const Claims(this.sub, this.role, this.exp);
  final String sub;
  final Role role;
  final int exp;
  bool get isAdmin => role == Role.admin;
}

/// HMAC-signed bearer tokens (payload.signature, 12h expiry) with salted, iterated password hashes
/// and two roles. A production system should use a vetted JWT library and a slow KDF such as argon2.
class Auth {
  Auth(this.secret);
  final String secret;

  static String newSalt([Random? rng]) {
    final r = rng ?? Random.secure();
    return base64Url.encode(List<int>.generate(12, (_) => r.nextInt(256)));
  }

  static String hashPassword(String password, String salt, {int rounds = 5000}) {
    var digest = utf8.encode('$salt:$password');
    for (var i = 0; i < rounds; i++) {
      digest = sha256.convert(digest).bytes;
    }
    return base64Url.encode(digest);
  }

  bool checkPassword(User u, String password) => _constantTimeEquals(hashPassword(password, u.salt), u.hash);

  String issue(User u, {Duration ttl = const Duration(hours: 12)}) {
    final exp = DateTime.now().add(ttl).millisecondsSinceEpoch ~/ 1000;
    final body = base64Url.encode(utf8.encode(jsonEncode({'sub': u.username, 'role': u.role.name, 'exp': exp})));
    return '$body.${_sign(body)}';
  }

  Claims? verify(String? header) {
    if (header == null || !header.startsWith('Bearer ')) return null;
    final parts = header.substring(7).split('.');
    if (parts.length != 2 || !_constantTimeEquals(_sign(parts[0]), parts[1])) return null;
    try {
      final c = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[0])))) as Map;
      final exp = c['exp'] as int;
      if (exp <= DateTime.now().millisecondsSinceEpoch ~/ 1000) return null;
      final role = Role.values.firstWhere((r) => r.name == c['role'], orElse: () => Role.viewer);
      return Claims('${c['sub']}', role, exp);
    } catch (_) {
      return null;
    }
  }

  String _sign(String body) => base64Url.encode(Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(body)).bytes);

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
