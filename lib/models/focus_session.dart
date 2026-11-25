/// A finished focus session synced from the Focus Desk app.
class FocusSession {
  FocusSession({
    required this.id,
    required this.task,
    required this.minutes,
    required this.at,
    this.tag = '',
  });

  final int id;
  final String task;
  final int minutes;
  final DateTime at;
  final String tag;

  Map<String, dynamic> toJson() => {
        'id': id,
        'task': task,
        'minutes': minutes,
        'at': at.toIso8601String(),
        'tag': tag,
      };

  factory FocusSession.fromJson(Map<String, dynamic> j) => FocusSession(
        id: (j['id'] ?? 0) as int,
        task: '${j['task']}',
        minutes: (j['minutes'] as num).toInt(),
        at: DateTime.parse(j['at'] as String),
        tag: '${j['tag'] ?? ''}',
      );
}
