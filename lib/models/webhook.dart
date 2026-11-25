const webhookEvents = ['order.created', 'order.updated', 'order.deleted', 'session.created'];

class WebhookSub {
  WebhookSub({
    required this.id,
    required this.url,
    required this.events,
    required this.secret,
    this.active = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toUtc();

  final int id;
  final String url;
  final List<String> events;
  final String secret;
  bool active;
  final DateTime createdAt;

  bool listensTo(String event) => active && (events.contains(event) || events.contains('*'));

  /// The secret is only shown once, when the webhook is created.
  Map<String, dynamic> toJson({bool withSecret = false}) => {
        'id': id,
        'url': url,
        'events': events,
        'active': active,
        'createdAt': createdAt.toIso8601String(),
        if (withSecret) 'secret': secret,
      };

  Map<String, dynamic> toStorage() => toJson(withSecret: true);

  factory WebhookSub.fromJson(Map<String, dynamic> j) => WebhookSub(
        id: j['id'] as int,
        url: '${j['url']}',
        events: ((j['events'] ?? const []) as List).map((e) => '$e').toList(),
        secret: '${j['secret']}',
        active: (j['active'] ?? true) as bool,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class WebhookDelivery {
  WebhookDelivery({
    required this.id,
    required this.webhookId,
    required this.event,
    required this.attempts,
    required this.ok,
    required this.statusCode,
    required this.at,
  });

  final int id;
  final int webhookId;
  final String event;
  final int attempts;
  final bool ok;
  final int? statusCode;
  final DateTime at;

  Map<String, dynamic> toJson() => {
        'id': id,
        'webhookId': webhookId,
        'event': event,
        'attempts': attempts,
        'ok': ok,
        'statusCode': statusCode,
        'at': at.toIso8601String(),
      };

  factory WebhookDelivery.fromJson(Map<String, dynamic> j) => WebhookDelivery(
        id: j['id'] as int,
        webhookId: j['webhookId'] as int,
        event: '${j['event']}',
        attempts: j['attempts'] as int,
        ok: j['ok'] as bool,
        statusCode: j['statusCode'] as int?,
        at: DateTime.parse(j['at'] as String),
      );
}
