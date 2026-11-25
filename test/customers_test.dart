import 'package:test/test.dart';
import 'helpers.dart';

void main() {
  late Harness h;
  setUp(() => h = Harness());

  test('create validates and rejects duplicate emails', () async {
    expect((await h.asAdmin('POST', '/customers', body: {'name': '', 'email': 'nope'})).statusCode, 400);
    final ok = await h.asAdmin('POST', '/customers', body: {'name': 'Lina', 'email': 'lina@example.com', 'tags': ['vip']});
    expect(ok.statusCode, 201);
    final dup = await h.asAdmin('POST', '/customers', body: {'name': 'Lina 2', 'email': 'LINA@example.com'});
    expect(dup.statusCode, 400);
  });

  test('list supports search, tag and city filters with lifetime value', () async {
    final vip = await Harness.json(await h.asAdmin('GET', '/customers?tag=vip')) as List;
    expect(vip.length, 2);
    expect(vip.first['lifetimeValue'], isA<num>());
    final cairo = await Harness.json(await h.asAdmin('GET', '/customers?city=cairo')) as List;
    expect(cairo.every((c) => c['city'] == 'Cairo'), isTrue);
    final q = await Harness.json(await h.asAdmin('GET', '/customers?q=salma')) as List;
    expect(q.single['name'], 'Salma Fathy');
  });

  test('detail includes recent orders', () async {
    final body = await Harness.json(await h.asAdmin('GET', '/customers/100'));
    expect(body['recentOrders'], isNotEmpty);
    expect(body['orders'], greaterThan(0));
  });

  test('patch updates fields', () async {
    final r = await h.asAdmin('PATCH', '/customers/100', body: {'city': 'Luxor', 'tags': ['a', 'b']});
    final body = await Harness.json(r);
    expect(body['city'], 'Luxor');
    expect(body['tags'], ['a', 'b']);
  });

  test('cannot delete a customer that has orders, can delete one that has none', () async {
    expect((await h.asAdmin('DELETE', '/customers/100')).statusCode, 409);
    final c = await Harness.json(await h.asAdmin('POST', '/customers', body: {'name': 'Tmp', 'email': 'tmp@example.com'}));
    expect((await h.asAdmin('DELETE', '/customers/${c['id']}')).statusCode, 204);
    expect((await h.asAdmin('GET', '/customers/${c['id']}')).statusCode, 404);
  });
}
