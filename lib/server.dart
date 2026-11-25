import 'package:shelf/shelf.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';
import 'ai.dart';
import 'auth.dart';
import 'middleware/auth_guard.dart';
import 'middleware/rate_limit.dart';
import 'middleware/request_id.dart';
import 'routes/admin.dart';
import 'routes/customers.dart';
import 'routes/focus.dart';
import 'routes/orders.dart';
import 'routes/webhooks.dart';
import 'services/webhooks.dart';
import 'store.dart';
import 'validation.dart';

const apiVersion = '2.0.0';

Handler buildHandler(
  Store store,
  Auth auth,
  AiProxy ai, {
  WebhookDispatcher? hooks,
  RateLimiter? limiter,
}) {
  final dispatcher = hooks ?? WebhookDispatcher(store);
  final router = Router();

  router.get('/health', (Request r) => jsonResponse({'ok': true, 'version': apiVersion}));

  router.post('/auth/login', (Request r) async {
    final b = await readJson(r);
    final u = store.userByName('${b['username']}');
    if (u == null || !auth.checkPassword(u, '${b['password']}')) {
      return jsonResponse({'error': 'invalid credentials'}, 401);
    }
    return jsonResponse({'token': auth.issue(u), 'role': u.role.name});
  });

  router.get('/auth/me', (Request r) {
    final c = claimsOf(r);
    return jsonResponse({'username': c.sub, 'role': c.role.name, 'expiresAt': c.exp});
  });

  router.mount('/orders', ordersRoutes(store, dispatcher).call);
  router.mount('/customers', customersRoutes(store).call);
  router.mount('/webhooks', webhooksRoutes(store, dispatcher).call);
  router.mount('/focus', focusRoutes(store, dispatcher).call);

  // Admin-only, even for reads.
  final admin = adminRoutes(store);
  router.mount('/admin', (Request r) => claimsOf(r).isAdmin ? admin.call(r) : jsonResponse({'error': 'admin role required'}, 403));

  router.get('/stats', (Request r) {
    final q = r.url.queryParameters;
    return jsonResponse(store.stats(from: DateTime.tryParse(q['from'] ?? ''), to: DateTime.tryParse(q['to'] ?? '')));
  });

  router.post('/ai/insights', (Request r) async => jsonResponse({'summary': await ai.summarize(store.stats())}));

  return Pipeline()
      .addMiddleware(corsHeaders())
      .addMiddleware(requestId())
      .addMiddleware(logRequests())
      .addMiddleware((limiter ?? RateLimiter()).middleware)
      .addMiddleware(handleErrors())
      .addMiddleware(authGuard(auth))
      .addMiddleware(requireAdminForWrites())
      .addHandler(router.call);
}

/// Turns ValidationError and unexpected exceptions into clean JSON responses.
Middleware handleErrors() => (inner) => (req) async {
      try {
        return await inner(req);
      } on ValidationError catch (e) {
        return jsonResponse({'error': 'validation failed', 'fields': e.errors}, 400);
      } catch (e) {
        return jsonResponse({'error': 'internal error'}, 500);
      }
    };
