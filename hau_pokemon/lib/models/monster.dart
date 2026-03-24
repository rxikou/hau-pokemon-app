class Monster {
  final int? id;
  final String name;
  final String type;
  final double lat;
  final double lng;
  final double radius;
  final String? imageUrl;

  const Monster({
    this.id,
    required this.name,
    required this.type,
    required this.lat,
    required this.lng,
    required this.radius,
    this.imageUrl,
  });

  factory Monster.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0.0;
    }

    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    return Monster(
      id: parseInt(json['id'] ?? json['monster_id']),
      name: (json['name'] ?? json['monster_name'] ?? '').toString(),
      type: (json['type'] ?? json['monster_type'] ?? '').toString(),
      lat: parseDouble(json['lat'] ?? json['latitude'] ?? json['spawn_latitude']),
      lng: parseDouble(
        json['lng'] ?? json['lon'] ?? json['longitude'] ?? json['spawn_longitude'],
      ),
      radius: parseDouble(
        json['radius'] ?? json['spawn_radius'] ?? json['spawn_radius_meters'],
      ),
      imageUrl: json['picture_url']?.toString() ??
          json['image_url']?.toString() ??
          json['imageUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'type': type,
      'lat': lat,
      'lng': lng,
      'radius': radius,
      if (imageUrl != null) 'image_url': imageUrl,
    };
  }

  Monster copyWith({
    int? id,
    String? name,
    String? type,
    double? lat,
    double? lng,
    double? radius,
    String? imageUrl,
  }) {
    return Monster(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      radius: radius ?? this.radius,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
