import 'dart:convert';
import 'package:shelf/shelf.dart';

/// Fixed-window limiter keyed by caller (IP or token subject). Adds the usual X-RateLimit headers.
class RateLimiter {
  RateLimiter({this.limit = 120, this.window = const Duration(minutes: 1), DateTime Function()? clock})
      : _now = clock ?? DateTime.now;

  final int limit;
  final Duration window;
  final DateTime Function() _now;
  final Map<String, _Bucket> _buckets = {};

  /// Returns remaining requests, or -1 when the caller is over the limit.
  ({int remaining, int resetSeconds}) hit(String key) {
    final now = _now();
    var b = _buckets[key];
    if (b == null || now.isAfter(b.start.add(window))) {
      b = _Bucket(now);
      _buckets[key] = b;
    }
    b.count++;
    final reset = b.start.add(window).difference(now).inSeconds.clamp(0, window.inSeconds);
    return (remaining: b.count > limit ? -1 : limit - b.count, resetSeconds: reset);
  }

  void _sweep() => _buckets.removeWhere((_, b) => _now().isAfter(b.start.add(window)));

  Middleware get middleware => (inner) => (Request req) async {
        if (_buckets.length > 5000) _sweep();
        final key = (req.headers['x-forwarded-for'] ?? req.headers['x-client'] ?? 'local').split(',').first.trim();
        final r = hit(key);
        final headers = {'x-ratelimit-limit': '$limit', 'x-ratelimit-reset': '${r.resetSeconds}'};
        if (r.remaining < 0) {
          return Response(429,
              body: jsonEncode({'error': 'rate limit exceeded', 'retryAfter': r.resetSeconds}),
              headers: {...headers, 'x-ratelimit-remaining': '0', 'retry-after': '${r.resetSeconds}', 'content-type': 'application/json'});
        }
        final res = await inner(req);
        return res.change(headers: {...headers, 'x-ratelimit-remaining': '${r.remaining}'});
      };
}

class _Bucket {
  _Bucket(this.start);
  final DateTime start;
  int count = 0;
}
