import 'dart:convert';
import 'dart:io';

/// Tiny JSON-file store so the demo runs with zero setup.
/// Swap for Postgres or Firestore behind the same interface in a real product.
class Store {
  Store(this.path);
  final String path;
  Map<String, dynamic> _data = {'orders': [], 'sessions': [], 'nextOrder': 1000};

  void load() {
    final f = File(path);
    if (f.existsSync()) _data = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    if ((_data['orders'] as List).isEmpty) _seed();
  }

  void _save() => File(path).writeAsStringSync(jsonEncode(_data));

  void _seed() {
    const names = ['Nour', 'Omar', 'Salma', 'Youssef', 'Mariam', 'Karim'];
    const states = ['paid', 'pending', 'refunded'];
    for (var i = 0; i < 18; i++) {
      addOrder(names[i % names.length], 25.0 + (i * 37 % 400), states[i % 3],
          DateTime.utc(2026, 11, 1).add(Duration(days: i)));
    }
  }

  List<Map<String, dynamic>> get orders => (_data['orders'] as List).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get sessions => (_data['sessions'] as List).cast<Map<String, dynamic>>();

  Map<String, dynamic> addOrder(String customer, double amount, String status, [DateTime? at]) {
    final id = _data['nextOrder'] as int;
    _data['nextOrder'] = id + 1;
    final o = {
      'id': id,
      'customer': customer,
      'amount': amount,
      'status': status,
      'date': (at ?? DateTime.now().toUtc()).toIso8601String(),
    };
    orders.add(o);
    _save();
    return o;
  }

  bool updateStatus(int id, String status) {
    final i = orders.indexWhere((o) => o['id'] == id);
    if (i < 0) return false;
    orders[i]['status'] = status;
    _save();
    return true;
  }

  void addSession(Map<String, dynamic> s) {
    sessions.add(s);
    _save();
  }

  Map<String, dynamic> stats() {
    final paid = orders.where((o) => o['status'] == 'paid');
    final byDay = <String, double>{};
    for (final o in paid) {
      final d = (o['date'] as String).substring(0, 10);
      byDay[d] = (byDay[d] ?? 0) + (o['amount'] as num).toDouble();
    }
    return {
      'revenue': paid.fold<double>(0, (a, o) => a + (o['amount'] as num).toDouble()),
      'orders': orders.length,
      'pending': orders.where((o) => o['status'] == 'pending').length,
      'revenueByDay': byDay,
    };
  }
}
