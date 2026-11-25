import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:relay/ai.dart';
import 'package:relay/auth.dart';
import 'package:relay/middleware/rate_limit.dart';
import 'package:relay/server.dart';
import 'package:relay/services/webhooks.dart';
import 'package:relay/store.dart';
import 'package:shelf/shelf.dart';

class Harness {
  Harness({int rateLimit = 1000, http.Client? hookClient}) {
    store = Store('unused', persist: false)..load(adminPass: 'pw');
    auth = Auth('test-secret');
    hooks = WebhookDispatcher(store,
        client: hookClient ?? MockClient((_) async => http.Response('ok', 200)),
        baseDelay: const Duration(milliseconds: 1));
    handler = buildHandler(store, auth, AiProxy(null), hooks: hooks, limiter: RateLimiter(limit: rateLimit));
    admin = auth.issue(store.userByName('admin')!);
    viewer = auth.issue(store.userByName('viewer')!);
  }

  late Store store;
  late Auth auth;
  late WebhookDispatcher hooks;
  late Handler handler;
  late String admin, viewer;

  Future<Response> call(String method, String path, {Object? body, String? token, Map<String, String>? headers}) =>
      Future.sync(() => handler(Request(method, Uri.parse('http://x$path'),
          body: body == null ? null : jsonEncode(body),
          headers: {if (token != null) 'authorization': 'Bearer $token', ...?headers})));

  Future<Response> asAdmin(String m, String p, {Object? body}) => call(m, p, body: body, token: admin);
  Future<Response> asViewer(String m, String p, {Object? body}) => call(m, p, body: body, token: viewer);

  static Future<dynamic> json(Response r) async => jsonDecode(await r.readAsString());
}
