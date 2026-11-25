import 'dart:convert';
import 'package:http/http.dart' as http;

/// Secure AI proxy: the API key lives only on this server, never in a client app.
/// If no key is set or the call fails, returns a rule-based summary so clients still work.
class AiProxy {
  AiProxy(this.apiKey, {http.Client? client}) : _client = client ?? http.Client();
  final String? apiKey;
  final http.Client _client;

  Future<String> summarize(Map<String, dynamic> stats) async {
    final fallback = _fallback(stats);
    if (apiKey == null || apiKey!.isEmpty) return fallback;
    try {
      final res = await _client
          .post(
            Uri.parse('https://api.openai.com/v1/chat/completions'),
            headers: {'Authorization': 'Bearer $apiKey', 'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': 'gpt-4o-mini',
              'messages': [
                {'role': 'system', 'content': 'You write two-sentence business summaries from JSON stats.'},
                {'role': 'user', 'content': jsonEncode(stats)},
              ],
            }),
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return fallback;
      return (jsonDecode(res.body)['choices'][0]['message']['content'] as String).trim();
    } catch (_) {
      return fallback;
    }
  }

  String _fallback(Map<String, dynamic> s) =>
      'Revenue is ${(s['revenue'] as num).toStringAsFixed(0)} across ${s['orders']} orders, '
      '${s['pending']} still pending.';
}
