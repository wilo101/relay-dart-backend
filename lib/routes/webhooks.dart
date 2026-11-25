import 'dart:math';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../middleware/auth_guard.dart';
import '../models/webhook.dart';
import '../pagination.dart';
import '../services/webhooks.dart';
import '../store.dart';
import '../validation.dart';

Router webhooksRoutes(Store store, WebhookDispatcher hooks) {
  final r = Router();

  r.get('/', (Request req) => jsonResponse(store.webhooks.map((w) => w.toJson()).toList()));

  r.post('/', (Request req) async {
    final b = await readJson(req);
    final url = '${b['url'] ?? ''}';
    final events = ((b['events'] ?? const ['*']) as List).map((e) => '$e').toList();
    final bad = events.where((e) => e != '*' && !webhookEvents.contains(e)).toList();
    if (!isHttpUrl(url)) return jsonResponse({'error': 'url must be http(s)'}, 400);
    if (bad.isNotEmpty) return jsonResponse({'error': 'unknown events', 'unknown': bad, 'allowed': webhookEvents}, 400);
    final rnd = Random.secure();
    final secret = 'whsec_${List.generate(24, (_) => rnd.nextInt(16).toRadixString(16)).join()}';
    final w = store.addWebhook(url, events, secret);
    store.log(claimsOf(req).sub, 'webhook.create', url);
    return jsonResponse(w.toJson(withSecret: true), 201);
  });

  r.patch('/<id|[0-9]+>', (Request req, String id) async {
    final w = store.webhooks.where((x) => x.id == int.parse(id)).firstOrNull;
    if (w == null) return jsonResponse({'error': 'not found'}, 404);
    final b = await readJson(req);
    if (b['active'] is bool) w.active = b['active'] as bool;
    store.save();
    return jsonResponse(w.toJson());
  });

  r.delete('/<id|[0-9]+>', (Request req, String id) {
    if (!store.deleteWebhook(int.parse(id))) return jsonResponse({'error': 'not found'}, 404);
    store.log(claimsOf(req).sub, 'webhook.delete', id);
    return Response(204);
  });

  /// Sends a test event so the receiver can check its signature code.
  r.post('/<id|[0-9]+>/test', (Request req, String id) async {
    final w = store.webhooks.where((x) => x.id == int.parse(id)).firstOrNull;
    if (w == null) return jsonResponse({'error': 'not found'}, 404);
    final ok = await hooks.deliver(w.id, w.url, w.secret, 'ping', {'message': 'test event'});
    return jsonResponse({'delivered': ok});
  });

  r.get('/deliveries', (Request req) {
    final q = req.url.queryParameters;
    final wid = int.tryParse(q['webhook_id'] ?? '');
    final list = store.deliveries.where((d) => wid == null || d.webhookId == wid).toList().reversed.toList();
    final page = paginate(list, PageParams.parse(q));
    return jsonResponse(page.items.map((d) => d.toJson()).toList(), 200, page.headers);
  });

  return r;
}
