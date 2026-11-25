import 'package:test/test.dart';
import 'helpers.dart';

void main() {
  late Harness h;
  setUp(() => h = Harness());

  test('validates and stores sessions', () async {
    expect((await h.asAdmin('POST', '/focus/sessions', body: {'task': '', 'minutes': 10})).statusCode, 400);
    expect((await h.asAdmin('POST', '/focus/sessions', body: {'task': 'x', 'minutes': 9999})).statusCode, 400);
    final ok = await h.asAdmin('POST', '/focus/sessions', body: {'task': 'Deep work', 'minutes': 45, 'tag': 'work'});
    expect(ok.statusCode, 201);
  });

  test('lists newest first, filters by tag', () async {
    await h.asAdmin('POST', '/focus/sessions', body: {'task': 'A', 'minutes': 10, 'tag': 'x'});
    final all = await Harness.json(await h.asAdmin('GET', '/focus/sessions')) as List;
    expect(all.first['task'], 'A');
    final tagged = await Harness.json(await h.asAdmin('GET', '/focus/sessions?tag=x')) as List;
    expect(tagged.length, 1);
  });

  test('stats count a streak of consecutive days', () async {
    final now = DateTime.now().toUtc();
    for (var i = 0; i < 3; i++) {
      h.store.addSession('s$i', 20, tag: 'work', at: now.subtract(Duration(days: i)));
    }
    final s = await Harness.json(await h.asAdmin('GET', '/focus/stats'));
    expect(s['streakDays'], 3);
    expect(s['minutesByTag']['work'], 60);
  });

  test('a gap breaks the streak', () async {
    final now = DateTime.now().toUtc();
    h.store.addSession('a', 10, at: now);
    h.store.addSession('b', 10, at: now.subtract(const Duration(days: 2)));
    final s = await Harness.json(await h.asAdmin('GET', '/focus/stats'));
    expect(s['streakDays'], 1);
  });
}
