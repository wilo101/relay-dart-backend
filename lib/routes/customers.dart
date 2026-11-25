import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../middleware/auth_guard.dart';
import '../pagination.dart';
import '../store.dart';
import '../validation.dart';

Router customersRoutes(Store store) {
  final r = Router();

  r.get('/', (Request req) {
    final q = req.url.queryParameters;
    final text = (q['q'] ?? '').toLowerCase();
    final tag = q['tag'];
    final city = (q['city'] ?? '').toLowerCase();
    var list = store.customers.where((c) {
      if (text.isNotEmpty && !c.name.toLowerCase().contains(text) && !c.email.toLowerCase().contains(text)) return false;
      if (tag != null && !c.tags.contains(tag)) return false;
      if (city.isNotEmpty && c.city.toLowerCase() != city) return false;
      return true;
    }).map(store.customerSummary).toList();
    final (field, desc) = parseSort(q['sort'], fallback: 'name', allowed: {'name', 'lifetimeValue', 'orders', 'createdAt'});
    list.sort((a, b) {
      final x = a[field] as Comparable?, y = b[field] as Comparable?;
      final c = x == null ? -1 : (y == null ? 1 : x.compareTo(y));
      return desc ? -c : c;
    });
    final page = paginate(list, PageParams.parse(q));
    return jsonResponse(page.items, 200, page.headers);
  });

  r.get('/<id|[0-9]+>', (Request req, String id) {
    final c = store.customer(int.parse(id));
    if (c == null) return jsonResponse({'error': 'not found'}, 404);
    final orders = store.orders.where((o) => o.customerId == c.id).toList()..sort((a, b) => b.date.compareTo(a.date));
    return jsonResponse({...store.customerSummary(c), 'recentOrders': orders.take(10).map((o) => o.toJson()).toList()});
  });

  r.post('/', (Request req) async {
    final b = await readJson(req);
    final errors = <String, String>{};
    final name = '${b['name'] ?? ''}'.trim();
    final email = '${b['email'] ?? ''}'.trim();
    if (name.isEmpty) errors['name'] = 'required';
    if (!isEmail(email)) errors['email'] = 'must be a valid email';
    if (store.customers.any((c) => c.email.toLowerCase() == email.toLowerCase())) errors['email'] = 'already exists';
    if (errors.isNotEmpty) return jsonResponse({'error': 'validation failed', 'fields': errors}, 400);
    final c = store.addCustomer(name, email,
        city: '${b['city'] ?? ''}', tags: ((b['tags'] ?? const []) as List).map((e) => '$e').toList());
    store.log(claimsOf(req).sub, 'customer.create', c.email);
    return jsonResponse(c.toJson(), 201);
  });

  r.patch('/<id|[0-9]+>', (Request req, String id) async {
    final c = store.customer(int.parse(id));
    if (c == null) return jsonResponse({'error': 'not found'}, 404);
    final b = await readJson(req);
    if (b['name'] != null) c.name = '${b['name']}'.trim();
    if (b['email'] != null) {
      if (!isEmail('${b['email']}')) return jsonResponse({'error': 'invalid email'}, 400);
      c.email = '${b['email']}';
    }
    if (b['city'] != null) c.city = '${b['city']}';
    if (b['tags'] is List) c.tags = (b['tags'] as List).map((e) => '$e').toList();
    store.save();
    store.log(claimsOf(req).sub, 'customer.update', c.email);
    return jsonResponse(c.toJson());
  });

  r.delete('/<id|[0-9]+>', (Request req, String id) {
    final n = int.parse(id);
    if (store.orders.any((o) => o.customerId == n)) {
      return jsonResponse({'error': 'customer has orders and cannot be deleted'}, 409);
    }
    if (!store.deleteCustomer(n)) return jsonResponse({'error': 'not found'}, 404);
    store.log(claimsOf(req).sub, 'customer.delete', '$n');
    return Response(204);
  });

  return r;
}
