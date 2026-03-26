class CaughtMonster {
  final int catchId;
  final int monsterId;
  final String name;
  final String type;
  final String? imageUrl;

  const CaughtMonster({
    required this.catchId,
    required this.monsterId,
    required this.name,
    required this.type,
    this.imageUrl,
  });

  factory CaughtMonster.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return CaughtMonster(
      catchId: parseInt(json['catch_id']),
      monsterId: parseInt(json['monster_id']),
      name: (json['monster_name'] ?? json['name'] ?? '').toString(),
      type: (json['monster_type'] ?? json['type'] ?? '').toString(),
      imageUrl: json['picture_url']?.toString() ??
          json['image_url']?.toString() ??
          json['imageUrl']?.toString(),
    );
  }
}
