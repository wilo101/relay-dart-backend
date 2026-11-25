import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../store.dart';

/// Signs and delivers events to subscribed URLs with retries and exponential backoff.
/// Each delivery carries `x-relay-event` and `x-relay-signature: sha256=<hmac of body>`.
class WebhookDispatcher {
  WebhookDispatcher(this.store, {http.Client? client, this.maxAttempts = 3, this.baseDelay = const Duration(milliseconds: 400)})
      : _client = client ?? http.Client();

  final Store store;
  final http.Client _client;
  final int maxAttempts;
  final Duration baseDelay;

  static String sign(String secret, String body) =>
      'sha256=${Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(body))}';

  /// Fire-and-forget: callers do not wait for delivery.
  void emit(String event, Map<String, dynamic> data) {
    final subs = store.webhooks.where((w) => w.listensTo(event)).toList();
    for (final w in subs) {
      deliver(w.id, w.url, w.secret, event, data);
    }
  }

  Future<bool> deliver(int id, String url, String secret, String event, Map<String, dynamic> data) async {
    final body = jsonEncode({'event': event, 'data': data, 'sentAt': DateTime.now().toUtc().toIso8601String()});
    int? status;
    var attempt = 0;
    var ok = false;
    while (attempt < maxAttempts && !ok) {
      attempt++;
      try {
        final res = await _client.post(Uri.parse(url), headers: {
          'content-type': 'application/json',
          'x-relay-event': event,
          'x-relay-signature': sign(secret, body),
        }, body: body).timeout(const Duration(seconds: 5));
        status = res.statusCode;
        ok = status >= 200 && status < 300;
      } catch (_) {
        status = null;
      }
      if (!ok && attempt < maxAttempts) await Future<void>.delayed(baseDelay * (1 << (attempt - 1)));
    }
    store.recordDelivery(id, event, attempt, ok, status);
    return ok;
  }
}
