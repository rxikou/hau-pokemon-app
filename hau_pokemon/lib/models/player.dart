class Player {
  final int id;
  final String username;
  final String passwordHash;

  const Player({
    required this.id,
    required this.username,
    required this.passwordHash,
  });

  Player copyWith({
    int? id,
    String? username,
    String? passwordHash,
  }) {
    return Player(
      id: id ?? this.id,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
    );
  }

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: (json['id'] as num).toInt(),
      username: (json['username'] as String?) ?? '',
      passwordHash: (json['passwordHash'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'passwordHash': passwordHash,
    };
  }
}
