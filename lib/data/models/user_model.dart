class UserModel {
  final String id;
  final String displayName;
  final String email;
  final String? photoUrl;
  final int points;
  final String badge;
  final String currentSkin;
  final List<String> unlockedSkins;
  final int submissionsCount;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.displayName,
    required this.email,
    this.photoUrl,
    required this.points,
    required this.badge,
    required this.currentSkin,
    required this.unlockedSkins,
    required this.submissionsCount,
    required this.createdAt,
  });

  UserModel copyWith({
    String? id,
    String? displayName,
    String? email,
    String? photoUrl,
    int? points,
    String? badge,
    String? currentSkin,
    List<String>? unlockedSkins,
    int? submissionsCount,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      points: points ?? this.points,
      badge: badge ?? this.badge,
      currentSkin: currentSkin ?? this.currentSkin,
      unlockedSkins: unlockedSkins ?? this.unlockedSkins,
      submissionsCount: submissionsCount ?? this.submissionsCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'points': points,
      'badge': badge,
      'currentSkin': currentSkin,
      'unlockedSkins': unlockedSkins,
      'submissionsCount': submissionsCount,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String,
      displayName: map['displayName'] as String,
      email: map['email'] as String,
      photoUrl: map['photoUrl'] as String?,
      points: map['points'] as int,
      badge: map['badge'] as String,
      currentSkin: map['currentSkin'] as String,
      unlockedSkins: List<String>.from(map['unlockedSkins'] as List? ?? []),
      submissionsCount: map['submissionsCount'] as int,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
