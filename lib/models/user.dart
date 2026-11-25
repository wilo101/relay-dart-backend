enum Role { admin, viewer }

class User {
  User({required this.id, required this.username, required this.hash, required this.salt, required this.role});

  final int id;
  final String username;
  final String hash;
  final String salt;
  final Role role;

  Map<String, dynamic> toPublicJson() => {'id': id, 'username': username, 'role': role.name};

  Map<String, dynamic> toStorage() => {'id': id, 'username': username, 'hash': hash, 'salt': salt, 'role': role.name};

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'] as int,
        username: '${j['username']}',
        hash: '${j['hash']}',
        salt: '${j['salt']}',
        role: Role.values.firstWhere((r) => r.name == j['role'], orElse: () => Role.viewer),
      );
}
