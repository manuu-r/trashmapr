class Point {
  final String id;
  final String imageUrl;
  final PointLocation location;
  final double weight; // 0.25-1.0
  final int category; // 1-4
  final String timestamp;
  final String? userId;

  Point({
    required this.id,
    required this.imageUrl,
    required this.location,
    required this.weight,
    required this.category,
    required this.timestamp,
    this.userId,
  });

  factory Point.fromJson(Map<String, dynamic> json) {
    return Point(
      id: json['id'] as String,
      imageUrl: json['image_url'] as String,
      location: PointLocation.fromJson(json['location'] as Map<String, dynamic>),
      weight: (json['weight'] as num).toDouble(),
      category: json['category'] as int,
      timestamp: json['timestamp'] as String,
      userId: json['user_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'image_url': imageUrl,
      'location': location.toJson(),
      'weight': weight,
      'category': category,
      'timestamp': timestamp,
      'user_id': userId,
    };
  }
}

class PointLocation {
  final double lat;
  final double lng;

  PointLocation({
    required this.lat,
    required this.lng,
  });

  factory PointLocation.fromJson(Map<String, dynamic> json) {
    return PointLocation(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lat': lat,
      'lng': lng,
    };
  }
}
