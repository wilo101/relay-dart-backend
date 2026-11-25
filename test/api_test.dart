import 'dart:convert';
import 'dart:io';
import 'package:relay/ai.dart';
import 'package:relay/auth.dart';
import 'package:relay/server.dart';
import 'package:relay/store.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  late Handler h;
  late String token;

  setUp(() async {
    final f = File('${Directory.systemTemp.createTempSync().path}/d.json');
    final store = Store(f.path)..load();
    final auth = Auth('s', 'admin', 'pw');
    h = buildHandler(store, auth, AiProxy(null));
    token = auth.login('admin', 'pw')!;
  });

  Request req(String m, String p, {Object? body, bool authed = true}) => Request(m, Uri.parse('http://x$p'),
      body: body == null ? null : jsonEncode(body),
      headers: {if (authed) 'authorization': 'Bearer $token'});

  test('rejects unauthenticated requests', () async {
    expect((await h(req('GET', '/orders', authed: false))).statusCode, 401);
  });

  test('login works and orders can be created and listed', () async {
    final login = await h(req('POST', '/auth/login', body: {'username': 'admin', 'password': 'pw'}, authed: false));
    expect(login.statusCode, 200);
    final created = await h(req('POST', '/orders', body: {'customer': 'Test', 'amount': 50}));
    expect(created.statusCode, 201);
    final list = jsonDecode(await (await h(req('GET', '/orders?q=test'))).readAsString()) as List;
    expect(list.length, 1);
  });

  test('AI proxy falls back without a key', () async {
    final r = await h(req('POST', '/ai/insights'));
    expect(jsonDecode(await r.readAsString())['summary'], contains('Revenue'));
  });
}
