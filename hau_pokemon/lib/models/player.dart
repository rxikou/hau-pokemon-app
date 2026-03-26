class Player {
  final int id;
  final String name;
  final String username;
  final String passwordHash;

  const Player({
    required this.id,
    required this.name,
    required this.username,
    required this.passwordHash,
  });

  String get displayName {
    final n = name.trim();
    if (n.isNotEmpty) return n;
    return username;
  }

  Player copyWith({
    int? id,
    String? name,
    String? username,
    String? passwordHash,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
    );
  }

  factory Player.fromJson(Map<String, dynamic> json) {
    final resolvedName =
        (json['name'] ?? json['player_name'] ?? json['display_name'] ?? '').toString();

    return Player(
      id: (json['id'] as num).toInt(),
      name: resolvedName,
      username: (json['username'] as String?) ?? '',
      passwordHash: (json['passwordHash'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'passwordHash': passwordHash,
    };
  }
}
