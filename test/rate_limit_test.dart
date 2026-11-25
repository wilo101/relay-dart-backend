import 'package:relay/middleware/rate_limit.dart';
import 'package:test/test.dart';
import 'helpers.dart';

void main() {
  test('counts down then blocks', () {
    final l = RateLimiter(limit: 3);
    expect(l.hit('a').remaining, 2);
    expect(l.hit('a').remaining, 1);
    expect(l.hit('a').remaining, 0);
    expect(l.hit('a').remaining, -1);
    expect(l.hit('b').remaining, 2);
  });

  test('window resets', () {
    var now = DateTime(2026, 1, 1);
    final l = RateLimiter(limit: 1, window: const Duration(seconds: 10), clock: () => now);
    l.hit('a');
    expect(l.hit('a').remaining, -1);
    now = now.add(const Duration(seconds: 11));
    expect(l.hit('a').remaining, 0);
  });

  test('HTTP returns 429 with retry-after once the limit is passed', () async {
    final h = Harness(rateLimit: 2);
    expect((await h.call('GET', '/health')).statusCode, 200);
    expect((await h.call('GET', '/health')).statusCode, 200);
    final blocked = await h.call('GET', '/health');
    expect(blocked.statusCode, 429);
    expect(blocked.headers['retry-after'], isNotNull);
  });

  test('successful responses carry rate limit headers and a request id', () async {
    final h = Harness();
    final r = await h.call('GET', '/health');
    expect(r.headers['x-ratelimit-limit'], '1000');
    expect(r.headers['x-request-id'], isNotEmpty);
  });
}
