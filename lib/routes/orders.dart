import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../middleware/auth_guard.dart';
import '../models/order.dart';
import '../pagination.dart';
import '../services/webhooks.dart';
import '../store.dart';
import '../validation.dart';

Router ordersRoutes(Store store, WebhookDispatcher hooks) {
  final r = Router();

  List<Order> filtered(Map<String, String> q) {
    final status = q['status'];
    final text = (q['q'] ?? '').toLowerCase();
    final customerId = int.tryParse(q['customer_id'] ?? '');
    final min = double.tryParse(q['min_amount'] ?? '');
    final max = double.tryParse(q['max_amount'] ?? '');
    final from = DateTime.tryParse(q['from'] ?? '');
    final to = DateTime.tryParse(q['to'] ?? '');
    final list = store.orders.where((o) {
      if (status != null && status.isNotEmpty && o.status != status) return false;
      if (customerId != null && o.customerId != customerId) return false;
      if (min != null && o.amount < min) return false;
      if (max != null && o.amount > max) return false;
      if (from != null && o.date.isBefore(from)) return false;
      if (to != null && o.date.isAfter(to)) return false;
      if (text.isNotEmpty && !o.customer.toLowerCase().contains(text) && !'${o.id}'.contains(text)) return false;
      return true;
    }).toList();
    final (field, desc) = parseSort(q['sort'], fallback: '-date', allowed: {'date', 'amount', 'customer', 'status', 'id'});
    int cmp(Order a, Order b) => switch (field) {
          'amount' => a.amount.compareTo(b.amount),
          'customer' => a.customer.compareTo(b.customer),
          'status' => a.status.compareTo(b.status),
          'id' => a.id.compareTo(b.id),
          _ => a.date.compareTo(b.date),
        };
    list.sort((a, b) => desc ? cmp(b, a) : cmp(a, b));
    return list;
  }

  // The body stays a plain JSON array so early clients keep working. Paging info is in x-* headers.
  r.get('/', (Request req) {
    final q = req.url.queryParameters;
    final page = paginate(filtered(q), PageParams.parse(q));
    return jsonResponse(page.items.map((o) => o.toJson()).toList(), 200, page.headers);
  });

  r.get('/export.csv', (Request req) {
    final rows = filtered(req.url.queryParameters);
    final b = StringBuffer('id,customer,amount,status,date,items\n');
    for (final o in rows) {
      b.writeln('${o.id},"${o.customer.replaceAll('"', '""')}",${o.amount.toStringAsFixed(2)},${o.status},${o.date.toIso8601String()},${o.items.length}');
    }
    return Response.ok(b.toString(), headers: {'content-type': 'text/csv', 'content-disposition': 'attachment; filename="orders.csv"'});
  });

  r.get('/<id|[0-9]+>', (Request req, String id) {
    final o = store.order(int.parse(id));
    return o == null ? jsonResponse({'error': 'not found'}, 404) : jsonResponse(o.toDetailJson());
  });

  r.post('/', (Request req) async {
    final b = await readJson(req);
    final errors = <String, String>{};
    final cid = (b['customerId'] as num?)?.toInt();
    final customer = cid == null ? null : store.customer(cid);
    if (customer == null) errors['customerId'] = 'unknown customer';
    final rawItems = b['items'];
    final items = <OrderItem>[];
    if (rawItems is List && rawItems.isNotEmpty) {
      for (final e in rawItems) {
        try {
          final it = OrderItem.fromJson(e as Map<String, dynamic>);
          if (it.qty < 1 || it.price < 0) throw const FormatException();
          items.add(it);
        } catch (_) {
          errors['items'] = 'each item needs sku, name, qty >= 1 and price >= 0';
          break;
        }
      }
    } else if ((b['amount'] as num?) != null && (b['amount'] as num) > 0) {
      // Backwards compatible with the first clients, which sent a single amount.
      items.add(OrderItem(sku: 'MISC', name: 'Order', qty: 1, price: (b['amount'] as num).toDouble()));
    } else {
      errors['items'] = 'at least one item is required';
    }
    final status = '${b['status'] ?? 'pending'}';
    if (!orderStatuses.contains(status)) errors['status'] = 'must be one of ${orderStatuses.join(', ')}';
    if (errors.isNotEmpty) return jsonResponse({'error': 'validation failed', 'fields': errors}, 400);
    final o = store.addOrder(customer: customer!, items: items, status: status, note: '${b['note'] ?? ''}');
    store.log(claimsOf(req).sub, 'order.create', '#${o.id}');
    hooks.emit('order.created', o.toJson());
    return jsonResponse(o.toDetailJson(), 201);
  });

  r.patch('/<id|[0-9]+>', (Request req, String id) async {
    final b = await readJson(req);
    final o = store.order(int.parse(id));
    if (o == null) return jsonResponse({'error': 'not found'}, 404);
    if (b.containsKey('status')) {
      final s = '${b['status']}';
      if (!orderStatuses.contains(s)) return jsonResponse({'error': 'invalid status', 'allowed': orderStatuses}, 400);
      o.setStatus(s, by: claimsOf(req).sub);
    }
    if (b.containsKey('note')) o.note = '${b['note']}';
    store.save();
    store.log(claimsOf(req).sub, 'order.update', '#${o.id}');
    hooks.emit('order.updated', o.toJson());
    return jsonResponse(o.toDetailJson());
  });

  /// Change many orders at once: {"ids":[1000,1001],"status":"shipped"}
  r.post('/bulk-status', (Request req) async {
    final b = await readJson(req);
    final status = '${b['status']}';
    final ids = ((b['ids'] ?? const []) as List).map((e) => (e as num).toInt()).toList();
    if (!orderStatuses.contains(status) || ids.isEmpty) {
      return jsonResponse({'error': 'ids and a valid status are required'}, 400);
    }
    final updated = <int>[];
    for (final id in ids) {
      final o = store.order(id);
      if (o == null) continue;
      o.setStatus(status, by: claimsOf(req).sub);
      updated.add(id);
      hooks.emit('order.updated', o.toJson());
    }
    store.save();
    store.log(claimsOf(req).sub, 'order.bulk', '${updated.length} orders -> $status');
    return jsonResponse({'updated': updated, 'missing': ids.where((i) => !updated.contains(i)).toList()});
  });

  r.delete('/<id|[0-9]+>', (Request req, String id) {
    final n = int.parse(id);
    final o = store.order(n);
    if (o == null) return jsonResponse({'error': 'not found'}, 404);
    store.deleteOrder(n);
    store.log(claimsOf(req).sub, 'order.delete', '#$n');
    hooks.emit('order.deleted', {'id': n});
    return Response(204);
  });

  return r;
}
