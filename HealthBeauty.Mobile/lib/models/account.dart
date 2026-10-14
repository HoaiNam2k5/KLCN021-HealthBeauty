class Account {
  final int id;
  final String email;
  final String? name;
  final String? role;

  Account({required this.id, required this.email, this.name, this.role});

  factory Account.fromJson(Map<String, dynamic> j) => Account(
        id: j['id'],
        email: j['email'] ?? '',
        name: j['name'],
        role: j['role'],
      );
}
