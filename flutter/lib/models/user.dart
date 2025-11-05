class User {
  final int id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final int totalPoints;
  final int totalUploads;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.totalPoints = 0,
    this.totalUploads = 0,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      displayName: json['name'],
      photoUrl: json['picture'],
      totalPoints: json['total_points'] ?? 0,
      totalUploads: json['total_uploads'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': displayName,
      'picture': photoUrl,
      'total_points': totalPoints,
      'total_uploads': totalUploads,
      'created_at': createdAt.toIso8601String(),
    };
  }

  User copyWith({
    int? id,
    String? email,
    String? displayName,
    String? photoUrl,
    int? totalPoints,
    int? totalUploads,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      totalPoints: totalPoints ?? this.totalPoints,
      totalUploads: totalUploads ?? this.totalUploads,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
