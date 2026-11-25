import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:relay/ai.dart';
import 'package:test/test.dart';
import 'helpers.dart';

void main() {
  const stats = {'revenue': 100, 'orders': 4, 'pending': 1};

  test('falls back without a key', () async {
    expect(await AiProxy(null).summarize(stats), contains('Revenue is 100'));
  });

  test('uses the model reply when the call succeeds', () async {
    final c = MockClient((_) async => http.Response(
        jsonEncode({'choices': [{'message': {'content': ' Nice week. '}}]}), 200));
    expect(await AiProxy('k', client: c).summarize(stats), 'Nice week.');
  });

  test('falls back on errors', () async {
    final c = MockClient((_) async => http.Response('x', 500));
    expect(await AiProxy('k', client: c).summarize(stats), contains('Revenue'));
  });

  test('endpoint works through the API', () async {
    final h = Harness();
    final body = await Harness.json(await h.asAdmin('POST', '/ai/insights'));
    expect(body['summary'], contains('Revenue'));
  });
}
