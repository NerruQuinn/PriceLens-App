class PriceEntryModel {
  final String id;
  final String productId;
  final double price;
  final String storeName;
  final String city;
  final String source;
  final String? photoUrl;
  final String? submittedBy;
  final String validationStatus;
  final int upvotes;
  final DateTime timestamp;

  PriceEntryModel({
    required this.id,
    required this.productId,
    required this.price,
    required this.storeName,
    required this.city,
    required this.source,
    this.photoUrl,
    this.submittedBy,
    required this.validationStatus,
    required this.upvotes,
    required this.timestamp,
  });

  PriceEntryModel copyWith({
    String? id,
    String? productId,
    double? price,
    String? storeName,
    String? city,
    String? source,
    String? photoUrl,
    String? submittedBy,
    String? validationStatus,
    int? upvotes,
    DateTime? timestamp,
  }) {
    return PriceEntryModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      price: price ?? this.price,
      storeName: storeName ?? this.storeName,
      city: city ?? this.city,
      source: source ?? this.source,
      photoUrl: photoUrl ?? this.photoUrl,
      submittedBy: submittedBy ?? this.submittedBy,
      validationStatus: validationStatus ?? this.validationStatus,
      upvotes: upvotes ?? this.upvotes,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'price': price,
      'storeName': storeName,
      'city': city,
      'source': source,
      'photoUrl': photoUrl,
      'submittedBy': submittedBy,
      'validationStatus': validationStatus,
      'upvotes': upvotes,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory PriceEntryModel.fromMap(Map<String, dynamic> map) {
    return PriceEntryModel(
      id: map['id'] as String,
      productId: map['productId'] as String,
      price: (map['price'] as num).toDouble(),
      storeName: map['storeName'] as String,
      city: map['city'] as String,
      source: map['source'] as String,
      photoUrl: map['photoUrl'] as String?,
      submittedBy: map['submittedBy'] as String?,
      validationStatus: map['validationStatus'] as String,
      upvotes: map['upvotes'] as int,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }
}
