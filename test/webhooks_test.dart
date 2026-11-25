import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:relay/services/webhooks.dart';
import 'package:test/test.dart';
import 'helpers.dart';

void main() {
  test('rejects bad urls and unknown events', () async {
    final h = Harness();
    expect((await h.asAdmin('POST', '/webhooks', body: {'url': 'ftp://x'})).statusCode, 400);
    expect((await h.asAdmin('POST', '/webhooks', body: {'url': 'https://a.example/h', 'events': ['nope']})).statusCode, 400);
  });

  test('secret is shown on create only', () async {
    final h = Harness();
    final created = await Harness.json(await h.asAdmin('POST', '/webhooks', body: {'url': 'https://a.example/h'}));
    expect(created['secret'], startsWith('whsec_'));
    final list = await Harness.json(await h.asAdmin('GET', '/webhooks')) as List;
    expect(list.single.containsKey('secret'), isFalse);
  });

  test('delivers signed payloads for subscribed events', () async {
    final seen = <http.Request>[];
    final h = Harness(hookClient: MockClient((req) async {
      seen.add(req);
      return http.Response('ok', 200);
    }));
    final w = await Harness.json(await h.asAdmin('POST', '/webhooks', body: {'url': 'https://a.example/h', 'events': ['order.created']}));
    await h.asAdmin('POST', '/orders', body: {'customerId': 100, 'amount': 20});
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(seen, hasLength(1));
    expect(seen.single.headers['x-relay-event'], 'order.created');
    expect(seen.single.headers['x-relay-signature'], WebhookDispatcher.sign(w['secret'] as String, seen.single.body));
    expect(jsonDecode(seen.single.body)['data']['customerId'], 100);
  });

  test('ignores events nobody subscribed to and inactive hooks', () async {
    var calls = 0;
    final h = Harness(hookClient: MockClient((_) async {
      calls++;
      return http.Response('ok', 200);
    }));
    final w = await Harness.json(await h.asAdmin('POST', '/webhooks', body: {'url': 'https://a.example/h', 'events': ['session.created']}));
    await h.asAdmin('POST', '/orders', body: {'customerId': 100, 'amount': 20});
    await h.asAdmin('PATCH', '/webhooks/${w['id']}', body: {'active': false});
    await h.asAdmin('POST', '/focus/sessions', body: {'task': 'x', 'minutes': 5});
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(calls, 0);
  });

  test('retries failures with backoff and records the delivery', () async {
    var calls = 0;
    final h = Harness(hookClient: MockClient((_) async {
      calls++;
      return http.Response('boom', calls < 3 ? 500 : 200);
    }));
    final w = h.store.addWebhook('https://a.example/h', ['*'], 's');
    final ok = await h.hooks.deliver(w.id, w.url, w.secret, 'order.created', {'id': 1});
    expect(ok, isTrue);
    expect(calls, 3);
    expect(h.store.deliveries.single.attempts, 3);
  });

  test('gives up after max attempts', () async {
    final h = Harness(hookClient: MockClient((_) async => http.Response('no', 500)));
    final w = h.store.addWebhook('https://a.example/h', ['*'], 's');
    expect(await h.hooks.deliver(w.id, w.url, w.secret, 'x', {}), isFalse);
    final d = await Harness.json(await h.asAdmin('GET', '/webhooks/deliveries'));
    expect(d.single['ok'], isFalse);
    expect(d.single['attempts'], 3);
  });
}
