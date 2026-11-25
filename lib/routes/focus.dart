import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../middleware/auth_guard.dart';
import '../pagination.dart';
import '../services/webhooks.dart';
import '../store.dart';
import '../validation.dart';

Router focusRoutes(Store store, WebhookDispatcher hooks) {
  final r = Router();

  r.get('/sessions', (Request req) {
    final q = req.url.queryParameters;
    final tag = q['tag'];
    final from = DateTime.tryParse(q['from'] ?? '');
    final list = store.sessions.where((s) => (tag == null || s.tag == tag) && (from == null || !s.at.isBefore(from))).toList()
      ..sort((a, b) => b.at.compareTo(a.at));
    final page = paginate(list, PageParams.parse(q));
    return jsonResponse(page.items.map((s) => s.toJson()).toList(), 200, page.headers);
  });

  r.post('/sessions', (Request req) async {
    final b = await readJson(req);
    final task = '${b['task'] ?? ''}'.trim();
    final minutes = (b['minutes'] as num?)?.toInt();
    if (task.isEmpty || minutes == null || minutes < 1 || minutes > 600) {
      return jsonResponse({'error': 'task and minutes (1-600) required'}, 400);
    }
    final s = store.addSession(task, minutes, tag: '${b['tag'] ?? ''}');
    hooks.emit('session.created', s.toJson());
    return jsonResponse(s.toJson(), 201);
  });

  r.delete('/sessions/<id|[0-9]+>', (Request req, String id) {
    final n = int.parse(id);
    final before = store.sessions.length;
    store.sessions.removeWhere((s) => s.id == n);
    store.save();
    return store.sessions.length == before ? jsonResponse({'error': 'not found'}, 404) : Response(204);
  });

  r.get('/stats', (Request req) => jsonResponse(store.focusStats()));

  return r;
}
