import 'package:test/test.dart';
import 'helpers.dart';

void main() {
  late Harness h;
  setUp(() => h = Harness());

  test('list is paginated and exposes totals in headers', () async {
    final r = await h.asAdmin('GET', '/orders?per_page=5&page=2');
    final body = await Harness.json(r) as List;
    expect(body.length, 5);
    expect(r.headers['x-total-count'], '24');
    expect(r.headers['x-total-pages'], '5');
    expect(r.headers['x-page'], '2');
  });

  test('per_page is capped at 100 and page past the end is empty', () async {
    final big = await h.asAdmin('GET', '/orders?per_page=9999');
    expect(big.headers['x-per-page'], '100');
    final past = await Harness.json(await h.asAdmin('GET', '/orders?page=99')) as List;
    expect(past, isEmpty);
  });

  test('filters by status, customer and amount range', () async {
    final paid = await Harness.json(await h.asAdmin('GET', '/orders?status=paid&per_page=100')) as List;
    expect(paid, isNotEmpty);
    expect(paid.every((o) => o['status'] == 'paid'), isTrue);

    final mine = await Harness.json(await h.asAdmin('GET', '/orders?customer_id=100&per_page=100')) as List;
    expect(mine.every((o) => o['customerId'] == 100), isTrue);

    final ranged = await Harness.json(await h.asAdmin('GET', '/orders?min_amount=50&max_amount=100&per_page=100')) as List;
    expect(ranged.every((o) => o['amount'] >= 50 && o['amount'] <= 100), isTrue);
  });

  test('sorts ascending and descending, ignoring unknown fields', () async {
    final asc = await Harness.json(await h.asAdmin('GET', '/orders?sort=amount&per_page=100')) as List;
    final amounts = asc.map((o) => o['amount'] as num).toList();
    expect(amounts, orderedEquals([...amounts]..sort()));
    final desc = await Harness.json(await h.asAdmin('GET', '/orders?sort=-amount&per_page=100')) as List;
    expect((desc.first['amount'] as num) >= (desc.last['amount'] as num), isTrue);
    expect((await h.asAdmin('GET', '/orders?sort=password')).statusCode, 200);
  });

  test('create validates input and computes the total from items', () async {
    final bad = await h.asAdmin('POST', '/orders', body: {'customerId': 99999, 'items': []});
    expect(bad.statusCode, 400);
    final ok = await h.asAdmin('POST', '/orders', body: {
      'customerId': 100,
      'items': [
        {'sku': 'A', 'name': 'Thing', 'qty': 2, 'price': 10.5},
        {'sku': 'B', 'name': 'Other', 'qty': 1, 'price': 4},
      ],
    });
    expect(ok.statusCode, 201);
    final body = await Harness.json(ok);
    expect(body['amount'], 25.0);
    expect(body['history'], hasLength(1));
  });

  test('legacy single-amount create still works', () async {
    final r = await h.asAdmin('POST', '/orders', body: {'customerId': 100, 'amount': 40});
    expect(r.statusCode, 201);
  });

  test('status changes are recorded in history', () async {
    final id = h.store.orders.first.id;
    final r = await h.asAdmin('PATCH', '/orders/$id', body: {'status': 'refunded'});
    expect(r.statusCode, 200);
    final body = await Harness.json(r);
    expect(body['status'], 'refunded');
    expect((body['history'] as List).last['by'], 'admin');
    expect((await h.asAdmin('PATCH', '/orders/$id', body: {'status': 'bogus'})).statusCode, 400);
  });

  test('bulk status updates existing ids and reports missing ones', () async {
    final ids = h.store.orders.take(3).map((o) => o.id).toList();
    final r = await h.asAdmin('POST', '/orders/bulk-status', body: {'ids': [...ids, 5], 'status': 'shipped'});
    final body = await Harness.json(r);
    expect(body['updated'], ids);
    expect(body['missing'], [5]);
  });

  test('detail, 404 and delete', () async {
    final id = h.store.orders.last.id;
    expect((await h.asAdmin('GET', '/orders/$id')).statusCode, 200);
    expect((await h.asAdmin('GET', '/orders/1')).statusCode, 404);
    expect((await h.asAdmin('DELETE', '/orders/$id')).statusCode, 204);
    expect((await h.asAdmin('GET', '/orders/$id')).statusCode, 404);
  });

  test('CSV export respects filters', () async {
    final r = await h.asAdmin('GET', '/orders/export.csv?status=pending');
    final csv = await r.readAsString();
    expect(r.headers['content-type'], 'text/csv');
    final lines = csv.trim().split('\n');
    expect(lines.first, startsWith('id,customer'));
    expect(lines.skip(1).every((l) => l.contains(',pending,')), isTrue);
  });

  test('stats include breakdowns and honour a date range', () async {
    final s = await Harness.json(await h.asAdmin('GET', '/stats'));
    expect(s['ordersByStatus'], isA<Map>());
    expect(s['topCustomers'], isNotEmpty);
    final none = await Harness.json(await h.asAdmin('GET', '/stats?from=2030-01-01'));
    expect(none['orders'], 0);
  });
}
