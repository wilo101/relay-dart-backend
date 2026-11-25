import 'package:relay/auth.dart';
import 'package:relay/models/user.dart';
import 'package:test/test.dart';
import 'helpers.dart';

void main() {
  group('Auth', () {
    test('hashes are salted and verify', () {
      final a = Auth.hashPassword('pw', 'salt1');
      expect(a, isNot(Auth.hashPassword('pw', 'salt2')));
      expect(a, Auth.hashPassword('pw', 'salt1'));
    });

    test('tampered tokens are rejected', () {
      final auth = Auth('s');
      final u = User(id: 1, username: 'a', hash: 'x', salt: 'y', role: Role.admin);
      final t = auth.issue(u);
      expect(auth.verify('Bearer $t')?.sub, 'a');
      expect(auth.verify('Bearer ${t}x'), isNull);
      expect(auth.verify('Bearer ${t.replaceFirst(RegExp('^.'), 'Z')}'), isNull);
      expect(auth.verify(null), isNull);
    });

    test('expired tokens are rejected', () {
      final auth = Auth('s');
      final u = User(id: 1, username: 'a', hash: 'x', salt: 'y', role: Role.viewer);
      expect(auth.verify('Bearer ${auth.issue(u, ttl: const Duration(seconds: -5))}'), isNull);
    });
  });

  group('HTTP auth', () {
    late Harness h;
    setUp(() => h = Harness());

    test('login returns token and role', () async {
      final r = await h.call('POST', '/auth/login', body: {'username': 'admin', 'password': 'pw'});
      expect(r.statusCode, 200);
      final body = await Harness.json(r);
      expect(body['role'], 'admin');
      expect(body['token'], isNotEmpty);
    });

    test('wrong password gives 401', () async {
      final r = await h.call('POST', '/auth/login', body: {'username': 'admin', 'password': 'nope'});
      expect(r.statusCode, 401);
    });

    test('protected routes need a token', () async {
      expect((await h.call('GET', '/orders')).statusCode, 401);
      expect((await h.call('GET', '/health')).statusCode, 200);
    });

    test('viewer can read but not write', () async {
      expect((await h.asViewer('GET', '/orders')).statusCode, 200);
      final w = await h.asViewer('POST', '/customers', body: {'name': 'A', 'email': 'a@b.co'});
      expect(w.statusCode, 403);
    });

    test('admin routes are admin only, even for reads', () async {
      expect((await h.asViewer('GET', '/admin/audit')).statusCode, 403);
      expect((await h.asAdmin('GET', '/admin/audit')).statusCode, 200);
    });

    test('malformed JSON is a 400, not a crash', () async {
      final r = await h.call('POST', '/auth/login', body: [1, 2]);
      expect(r.statusCode, 400);
    });
  });
}
