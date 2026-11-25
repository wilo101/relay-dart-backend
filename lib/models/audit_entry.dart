/// Who did what, kept for the admin audit log.
class AuditEntry {
  AuditEntry({required this.id, required this.actor, required this.action, required this.target, required this.at});

  final int id;
  final String actor;
  final String action;
  final String target;
  final DateTime at;

  Map<String, dynamic> toJson() =>
      {'id': id, 'actor': actor, 'action': action, 'target': target, 'at': at.toIso8601String()};

  factory AuditEntry.fromJson(Map<String, dynamic> j) => AuditEntry(
        id: j['id'] as int,
        actor: '${j['actor']}',
        action: '${j['action']}',
        target: '${j['target']}',
        at: DateTime.parse(j['at'] as String),
      );
}
