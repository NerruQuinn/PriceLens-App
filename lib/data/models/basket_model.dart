class BasketModel {
  final String id;
  final String userId;
  final List<BasketItemModel> items;
  final double totalEstimate;
  final String? photoUrl;
  final DateTime createdAt;

  BasketModel({
    required this.id,
    required this.userId,
    required this.items,
    required this.totalEstimate,
    this.photoUrl,
    required this.createdAt,
  });

  BasketModel copyWith({
    String? id,
    String? userId,
    List<BasketItemModel>? items,
    double? totalEstimate,
    String? photoUrl,
    DateTime? createdAt,
  }) {
    return BasketModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      items: items ?? this.items,
      totalEstimate: totalEstimate ?? this.totalEstimate,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'items': items.map((item) => item.toMap()).toList(),
      'totalEstimate': totalEstimate,
      'photoUrl': photoUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory BasketModel.fromMap(Map<String, dynamic> map) {
    return BasketModel(
      id: map['id'] as String,
      userId: map['userId'] as String,
      items: (map['items'] as List<dynamic>?)
              ?.map((item) => BasketItemModel.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      totalEstimate: (map['totalEstimate'] as num).toDouble(),
      photoUrl: map['photoUrl'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}

class BasketItemModel {
  final String name;
  final String? brand;
  final int quantity;
  final double unitPriceEstimate;
  final double subtotal;
  final String confidence;
  final String cheapestStore;

  BasketItemModel({
    required this.name,
    this.brand,
    required this.quantity,
    required this.unitPriceEstimate,
    required this.subtotal,
    required this.confidence,
    required this.cheapestStore,
  });

  BasketItemModel copyWith({
    String? name,
    String? brand,
    int? quantity,
    double? unitPriceEstimate,
    double? subtotal,
    String? confidence,
    String? cheapestStore,
  }) {
    return BasketItemModel(
      name: name ?? this.name,
      brand: brand ?? this.brand,
      quantity: quantity ?? this.quantity,
      unitPriceEstimate: unitPriceEstimate ?? this.unitPriceEstimate,
      subtotal: subtotal ?? this.subtotal,
      confidence: confidence ?? this.confidence,
      cheapestStore: cheapestStore ?? this.cheapestStore,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'brand': brand,
      'quantity': quantity,
      'unitPriceEstimate': unitPriceEstimate,
      'subtotal': subtotal,
      'confidence': confidence,
      'cheapestStore': cheapestStore,
    };
  }

  factory BasketItemModel.fromMap(Map<String, dynamic> map) {
    return BasketItemModel(
      name: map['name'] as String,
      brand: map['brand'] as String?,
      quantity: map['quantity'] as int,
      unitPriceEstimate: (map['unitPriceEstimate'] as num).toDouble(),
      subtotal: (map['subtotal'] as num).toDouble(),
      confidence: map['confidence'] as String,
      cheapestStore: map['cheapestStore'] as String,
    );
  }
}
