import 'dart:convert';
import 'dart:io';
import 'auth.dart';
import 'models/audit_entry.dart';
import 'models/customer.dart';
import 'models/focus_session.dart';
import 'models/order.dart';
import 'models/user.dart';
import 'models/webhook.dart';

/// JSON-file store so the project runs with zero setup.
/// Every collection sits behind a method here, so it can be swapped for Postgres without touching the routes.
class Store {
  Store(this.path, {this.persist = true});
  final String path;
  final bool persist;

  final List<Customer> customers = [];
  final List<Order> orders = [];
  final List<FocusSession> sessions = [];
  final List<User> users = [];
  final List<WebhookSub> webhooks = [];
  final List<WebhookDelivery> deliveries = [];
  final List<AuditEntry> audit = [];
  final Map<String, int> _seq = {};

  int _next(String k, [int start = 1]) {
    final v = _seq[k] ?? start;
    _seq[k] = v + 1;
    return v;
  }

  void load({String adminUser = 'admin', String adminPass = 'admin123'}) {
    final f = File(path);
    if (persist && f.existsSync()) {
      final d = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      customers.addAll(_list(d['customers']).map(Customer.fromJson));
      orders.addAll(_list(d['orders']).map(Order.fromJson));
      sessions.addAll(_list(d['sessions']).map(FocusSession.fromJson));
      users.addAll(_list(d['users']).map(User.fromJson));
      webhooks.addAll(_list(d['webhooks']).map(WebhookSub.fromJson));
      deliveries.addAll(_list(d['deliveries']).map(WebhookDelivery.fromJson));
      audit.addAll(_list(d['audit']).map(AuditEntry.fromJson));
      _seq.addAll(((d['seq'] ?? {}) as Map).map((k, v) => MapEntry('$k', v as int)));
    }
    if (users.isEmpty) {
      addUser(adminUser, adminPass, Role.admin);
      addUser('viewer', 'viewer123', Role.viewer);
    }
    if (customers.isEmpty) _seed();
  }

  Iterable<Map<String, dynamic>> _list(Object? v) => ((v ?? const []) as List).cast<Map<String, dynamic>>();

  void save() {
    if (!persist) return;
    File(path).writeAsStringSync(jsonEncode({
      'customers': customers.map((c) => c.toJson()).toList(),
      'orders': orders.map((o) => o.toStorage()).toList(),
      'sessions': sessions.map((s) => s.toJson()).toList(),
      'users': users.map((u) => u.toStorage()).toList(),
      'webhooks': webhooks.map((w) => w.toStorage()).toList(),
      'deliveries': deliveries.map((d) => d.toJson()).toList(),
      'audit': audit.map((a) => a.toJson()).toList(),
      'seq': _seq,
    }));
  }

  void _seed() {
    const people = [
      ('Nour Hassan', 'nour@example.com', 'Cairo', ['vip']),
      ('Omar Adel', 'omar@example.com', 'Giza', <String>[]),
      ('Salma Fathy', 'salma@example.com', 'Alexandria', ['wholesale']),
      ('Youssef Samir', 'youssef@example.com', 'Cairo', <String>[]),
      ('Mariam Khaled', 'mariam@example.com', 'Mansoura', ['vip']),
      ('Karim Nabil', 'karim@example.com', 'Giza', <String>[]),
    ];
    for (final p in people) {
      addCustomer(p.$1, p.$2, city: p.$3, tags: p.$4);
    }
    const catalog = [
      ('SKU-100', 'Linen shirt', 38.0),
      ('SKU-210', 'Canvas tote', 22.0),
      ('SKU-305', 'Ceramic mug', 14.5),
      ('SKU-412', 'Notebook set', 18.0),
    ];
    const states = ['paid', 'pending', 'refunded', 'shipped', 'paid', 'cancelled'];
    for (var i = 0; i < 24; i++) {
      final c = customers[i % customers.length];
      final a = catalog[i % catalog.length];
      final b = catalog[(i + 2) % catalog.length];
      final items = [
        OrderItem(sku: a.$1, name: a.$2, qty: 1 + i % 3, price: a.$3),
        OrderItem(sku: b.$1, name: b.$2, qty: 1, price: b.$3),
      ];
      addOrder(
        customer: c,
        items: items,
        status: states[i % states.length],
        at: DateTime.utc(2026, 11, 1).add(Duration(days: i % 24, hours: i * 3 % 24)),
      );
    }
    sessions.addAll([
      FocusSession(id: _next('session'), task: 'Write proposal', minutes: 25, at: DateTime.utc(2026, 11, 20, 9), tag: 'work'),
      FocusSession(id: _next('session'), task: 'Study Dart', minutes: 50, at: DateTime.utc(2026, 11, 21, 18), tag: 'study'),
    ]);
    save();
  }

  // ---- users
  User addUser(String username, String password, Role role) {
    final salt = Auth.newSalt();
    final u = User(id: _next('user'), username: username, hash: Auth.hashPassword(password, salt), salt: salt, role: role);
    users.add(u);
    save();
    return u;
  }

  User? userByName(String name) {
    for (final u in users) {
      if (u.username == name) return u;
    }
    return null;
  }

  // ---- customers
  Customer addCustomer(String name, String email, {String city = '', List<String> tags = const []}) {
    final c = Customer(id: _next('customer', 100), name: name, email: email, city: city, tags: tags);
    customers.add(c);
    save();
    return c;
  }

  Customer? customer(int id) {
    for (final c in customers) {
      if (c.id == id) return c;
    }
    return null;
  }

  bool deleteCustomer(int id) {
    final before = customers.length;
    customers.removeWhere((c) => c.id == id);
    save();
    return customers.length != before;
  }

  /// Per-customer totals computed from paid and shipped orders.
  Map<String, dynamic> customerSummary(Customer c) {
    final mine = orders.where((o) => o.customerId == c.id).toList();
    final spent = mine.where((o) => o.status == 'paid' || o.status == 'shipped').fold<double>(0, (a, o) => a + o.amount);
    mine.sort((a, b) => b.date.compareTo(a.date));
    return {
      ...c.toJson(),
      'orders': mine.length,
      'lifetimeValue': double.parse(spent.toStringAsFixed(2)),
      'lastOrderAt': mine.isEmpty ? null : mine.first.date.toIso8601String(),
    };
  }

  // ---- orders
  Order addOrder({
    required Customer customer,
    required List<OrderItem> items,
    String status = 'pending',
    String note = '',
    DateTime? at,
  }) {
    final total = items.fold<double>(0, (a, i) => a + i.total);
    final o = Order(
      id: _next('order', 1000),
      customer: customer.name,
      customerId: customer.id,
      amount: double.parse(total.toStringAsFixed(2)),
      status: status,
      date: at ?? DateTime.now().toUtc(),
      items: items,
      note: note,
    );
    orders.add(o);
    save();
    return o;
  }

  Order? order(int id) {
    for (final o in orders) {
      if (o.id == id) return o;
    }
    return null;
  }

  bool deleteOrder(int id) {
    final before = orders.length;
    orders.removeWhere((o) => o.id == id);
    save();
    return orders.length != before;
  }

  // ---- sessions
  FocusSession addSession(String task, int minutes, {String tag = '', DateTime? at}) {
    final s = FocusSession(id: _next('session'), task: task, minutes: minutes, at: at ?? DateTime.now().toUtc(), tag: tag);
    sessions.add(s);
    save();
    return s;
  }

  // ---- webhooks and audit
  WebhookSub addWebhook(String url, List<String> events, String secret) {
    final w = WebhookSub(id: _next('webhook'), url: url, events: events, secret: secret);
    webhooks.add(w);
    save();
    return w;
  }

  bool deleteWebhook(int id) {
    final before = webhooks.length;
    webhooks.removeWhere((w) => w.id == id);
    save();
    return webhooks.length != before;
  }

  WebhookDelivery recordDelivery(int webhookId, String event, int attempts, bool ok, int? status) {
    final d = WebhookDelivery(
        id: _next('delivery'), webhookId: webhookId, event: event, attempts: attempts, ok: ok, statusCode: status, at: DateTime.now().toUtc());
    deliveries.add(d);
    if (deliveries.length > 500) deliveries.removeRange(0, deliveries.length - 500);
    save();
    return d;
  }

  void log(String actor, String action, String target) {
    audit.add(AuditEntry(id: _next('audit'), actor: actor, action: action, target: target, at: DateTime.now().toUtc()));
    if (audit.length > 1000) audit.removeRange(0, audit.length - 1000);
    save();
  }

  // ---- stats
  Map<String, dynamic> stats({DateTime? from, DateTime? to}) {
    bool inRange(Order o) => (from == null || !o.date.isBefore(from)) && (to == null || !o.date.isAfter(to));
    final scoped = orders.where(inRange).toList();
    final paid = scoped.where((o) => o.status == 'paid' || o.status == 'shipped').toList();
    final byDay = <String, double>{};
    final byStatus = <String, int>{};
    final byCustomer = <String, double>{};
    final bySku = <String, int>{};
    for (final o in scoped) {
      byStatus[o.status] = (byStatus[o.status] ?? 0) + 1;
    }
    for (final o in paid) {
      final d = o.date.toIso8601String().substring(0, 10);
      byDay[d] = (byDay[d] ?? 0) + o.amount;
      byCustomer[o.customer] = (byCustomer[o.customer] ?? 0) + o.amount;
      for (final i in o.items) {
        bySku[i.name] = (bySku[i.name] ?? 0) + i.qty;
      }
    }
    final revenue = paid.fold<double>(0, (a, o) => a + o.amount);
    List<MapEntry<String, T>> top<T extends num>(Map<String, T> m) =>
        (m.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(5).toList();
    return {
      'revenue': revenue,
      'orders': scoped.length,
      'pending': scoped.where((o) => o.status == 'pending').length,
      'averageOrder': paid.isEmpty ? 0 : double.parse((revenue / paid.length).toStringAsFixed(2)),
      'revenueByDay': byDay,
      'ordersByStatus': byStatus,
      'topCustomers': [for (final e in top(byCustomer)) {'name': e.key, 'revenue': e.value}],
      'topProducts': [for (final e in top(bySku)) {'name': e.key, 'units': e.value}],
    };
  }

  Map<String, dynamic> focusStats() {
    final byDay = <String, int>{};
    final byTag = <String, int>{};
    for (final s in sessions) {
      final d = s.at.toIso8601String().substring(0, 10);
      byDay[d] = (byDay[d] ?? 0) + s.minutes;
      byTag[s.tag.isEmpty ? 'untagged' : s.tag] = (byTag[s.tag.isEmpty ? 'untagged' : s.tag] ?? 0) + s.minutes;
    }
    // Streak = consecutive days with at least one session, ending today or yesterday.
    var streak = 0;
    var day = DateTime.now().toUtc();
    if (!byDay.containsKey(_d(day))) day = day.subtract(const Duration(days: 1));
    while (byDay.containsKey(_d(day))) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return {
      'totalMinutes': sessions.fold<int>(0, (a, s) => a + s.minutes),
      'sessions': sessions.length,
      'minutesByDay': byDay,
      'minutesByTag': byTag,
      'streakDays': streak,
    };
  }

  static String _d(DateTime d) => d.toIso8601String().substring(0, 10);
}
