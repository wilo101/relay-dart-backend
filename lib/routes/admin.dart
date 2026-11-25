import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../middleware/auth_guard.dart';
import '../pagination.dart';
import '../store.dart';

Router adminRoutes(Store store) {
  final r = Router();

  r.get('/audit', (Request req) {
    final q = req.url.queryParameters;
    final actor = q['actor'];
    final list = store.audit.where((a) => actor == null || a.actor == actor).toList().reversed.toList();
    final page = paginate(list, PageParams.parse(q));
    return jsonResponse(page.items.map((a) => a.toJson()).toList(), 200, page.headers);
  });

  r.get('/users', (Request req) => jsonResponse(store.users.map((u) => u.toPublicJson()).toList()));

  return r;
}
