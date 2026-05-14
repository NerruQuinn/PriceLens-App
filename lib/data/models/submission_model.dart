class SubmissionModel {
  final String id;
  final String userId;
  final String productId;
  final double price;
  final String storeName;
  final String city;
  final String? photoUrl;
  final String status;
  final double aiValidationScore;
  final String? aiReason;
  final int upvotes;
  final List<String> upvotedBy;
  final DateTime timestamp;

  SubmissionModel({
    required this.id,
    required this.userId,
    required this.productId,
    required this.price,
    required this.storeName,
    required this.city,
    this.photoUrl,
    required this.status,
    required this.aiValidationScore,
    this.aiReason,
    required this.upvotes,
    required this.upvotedBy,
    required this.timestamp,
  });

  SubmissionModel copyWith({
    String? id,
    String? userId,
    String? productId,
    double? price,
    String? storeName,
    String? city,
    String? photoUrl,
    String? status,
    double? aiValidationScore,
    String? aiReason,
    int? upvotes,
    List<String>? upvotedBy,
    DateTime? timestamp,
  }) {
    return SubmissionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      productId: productId ?? this.productId,
      price: price ?? this.price,
      storeName: storeName ?? this.storeName,
      city: city ?? this.city,
      photoUrl: photoUrl ?? this.photoUrl,
      status: status ?? this.status,
      aiValidationScore: aiValidationScore ?? this.aiValidationScore,
      aiReason: aiReason ?? this.aiReason,
      upvotes: upvotes ?? this.upvotes,
      upvotedBy: upvotedBy ?? this.upvotedBy,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'productId': productId,
      'price': price,
      'storeName': storeName,
      'city': city,
      'photoUrl': photoUrl,
      'status': status,
      'aiValidationScore': aiValidationScore,
      'aiReason': aiReason,
      'upvotes': upvotes,
      'upvotedBy': upvotedBy,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory SubmissionModel.fromMap(Map<String, dynamic> map) {
    return SubmissionModel(
      id: map['id'] as String,
      userId: map['userId'] as String,
      productId: map['productId'] as String,
      price: (map['price'] as num).toDouble(),
      storeName: map['storeName'] as String,
      city: map['city'] as String,
      photoUrl: map['photoUrl'] as String?,
      status: map['status'] as String,
      aiValidationScore: (map['aiValidationScore'] as num).toDouble(),
      aiReason: map['aiReason'] as String?,
      upvotes: map['upvotes'] as int,
      upvotedBy: List<String>.from(map['upvotedBy'] as List? ?? []),
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }
}
