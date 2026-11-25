const orderStatuses = ['pending', 'paid', 'shipped', 'refunded', 'cancelled'];

/// One line on an order.
class OrderItem {
  const OrderItem({required this.sku, required this.name, required this.qty, required this.price});
  final String sku;
  final String name;
  final int qty;
  final double price;

  double get total => qty * price;

  Map<String, dynamic> toJson() => {'sku': sku, 'name': name, 'qty': qty, 'price': price};

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
        sku: '${j['sku']}',
        name: '${j['name']}',
        qty: (j['qty'] as num).toInt(),
        price: (j['price'] as num).toDouble(),
      );
}

/// A status change, kept so the order detail screen can show a timeline.
class StatusChange {
  const StatusChange({required this.status, required this.at, this.by = 'system'});
  final String status;
  final DateTime at;
  final String by;

  Map<String, dynamic> toJson() => {'status': status, 'at': at.toIso8601String(), 'by': by};

  factory StatusChange.fromJson(Map<String, dynamic> j) =>
      StatusChange(status: '${j['status']}', at: DateTime.parse(j['at'] as String), by: '${j['by'] ?? 'system'}');
}

class Order {
  Order({
    required this.id,
    required this.customer,
    required this.amount,
    required this.status,
    required this.date,
    this.customerId,
    this.items = const [],
    this.note = '',
    List<StatusChange>? history,
  }) : history = history ?? [StatusChange(status: status, at: date)];

  final int id;
  String customer;
  int? customerId;
  double amount;
  String status;
  final DateTime date;
  List<OrderItem> items;
  String note;
  final List<StatusChange> history;

  void setStatus(String next, {String by = 'system', DateTime? at}) {
    if (next == status) return;
    status = next;
    history.add(StatusChange(status: next, at: at ?? DateTime.now().toUtc(), by: by));
  }

  /// Compact shape used by list endpoints (kept compatible with the first Pulse and Focus Desk clients).
  Map<String, dynamic> toJson() => {
        'id': id,
        'customer': customer,
        'customerId': customerId,
        'amount': amount,
        'status': status,
        'date': date.toIso8601String(),
        'itemCount': items.length,
      };

  /// Full shape used by the detail endpoint.
  Map<String, dynamic> toDetailJson() => {
        ...toJson(),
        'items': items.map((i) => i.toJson()).toList(),
        'note': note,
        'history': history.map((h) => h.toJson()).toList(),
      };

  /// Persistence shape.
  Map<String, dynamic> toStorage() => toDetailJson();

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: j['id'] as int,
        customer: '${j['customer']}',
        customerId: j['customerId'] as int?,
        amount: (j['amount'] as num).toDouble(),
        status: '${j['status']}',
        date: DateTime.parse(j['date'] as String),
        items: ((j['items'] ?? const []) as List).map((e) => OrderItem.fromJson(e as Map<String, dynamic>)).toList(),
        note: '${j['note'] ?? ''}',
        history: ((j['history'] ?? const []) as List)
            .map((e) => StatusChange.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
