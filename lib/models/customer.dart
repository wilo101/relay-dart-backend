/// A customer who places orders.
class Customer {
  Customer({
    required this.id,
    required this.name,
    required this.email,
    this.city = '',
    this.tags = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toUtc();

  final int id;
  String name;
  String email;
  String city;
  List<String> tags;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'city': city,
        'tags': tags,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
        id: j['id'] as int,
        name: j['name'] as String,
        email: j['email'] as String,
        city: (j['city'] ?? '') as String,
        tags: ((j['tags'] ?? const []) as List).map((e) => '$e').toList(),
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}
