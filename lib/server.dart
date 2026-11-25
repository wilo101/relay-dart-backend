import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';
import 'ai.dart';
import 'auth.dart';
import 'store.dart';

Response _json(Object body, [int status = 200]) =>
    Response(status, body: jsonEncode(body), headers: {'content-type': 'application/json'});

Handler buildHandler(Store store, Auth auth, AiProxy ai) {
  final router = Router();

  router.get('/health', (Request r) => _json({'ok': true}));

  router.post('/auth/login', (Request r) async {
    final b = jsonDecode(await r.readAsString()) as Map<String, dynamic>;
    final t = auth.login('${b['username']}', '${b['password']}');
    return t == null ? _json({'error': 'invalid credentials'}, 401) : _json({'token': t});
  });

  router.get('/orders', (Request r) {
    final status = r.url.queryParameters['status'];
    final q = (r.url.queryParameters['q'] ?? '').toLowerCase();
    final list = store.orders
        .where((o) => (status == null || o['status'] == status) && '${o['customer']}'.toLowerCase().contains(q))
        .toList();
    return _json(list);
  });

  router.post('/orders', (Request r) async {
    final b = jsonDecode(await r.readAsString()) as Map<String, dynamic>;
    final amount = (b['amount'] as num?)?.toDouble();
    if (b['customer'] == null || amount == null || amount <= 0) {
      return _json({'error': 'customer and positive amount required'}, 400);
    }
    return _json(store.addOrder('${b['customer']}', amount, '${b['status'] ?? 'pending'}'), 201);
  });

  router.patch('/orders/<id>', (Request r, String id) async {
    final b = jsonDecode(await r.readAsString()) as Map<String, dynamic>;
    final ok = store.updateStatus(int.parse(id), '${b['status']}');
    return ok ? _json({'ok': true}) : _json({'error': 'not found'}, 404);
  });

  router.get('/stats', (Request r) => _json(store.stats()));

  router.post('/ai/insights', (Request r) async => _json({'summary': await ai.summarize(store.stats())}));

  // Focus Desk sync
  router.get('/focus/sessions', (Request r) => _json(store.sessions));
  router.post('/focus/sessions', (Request r) async {
    final b = jsonDecode(await r.readAsString()) as Map<String, dynamic>;
    store.addSession({'task': b['task'], 'minutes': b['minutes'], 'at': DateTime.now().toUtc().toIso8601String()});
    return _json({'ok': true}, 201);
  });

  const open = {'/health', '/auth/login'};
  final protected = Pipeline().addMiddleware((inner) => (req) {
        if (open.contains('/${req.url.path}') || auth.verify(req.headers['authorization'])) return inner(req);
        return _json({'error': 'unauthorized'}, 401);
      }).addHandler(router.call);

  return Pipeline()
      .addMiddleware(corsHeaders())
      .addMiddleware(logRequests())
      .addHandler(protected);
}
