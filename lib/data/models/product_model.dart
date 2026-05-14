class ProductModel {
  final String id;
  final String name;
  final String brand;
  final String category;
  final String? imageUrl;
  final DateTime lastUpdated;

  ProductModel({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    this.imageUrl,
    required this.lastUpdated,
  });

  ProductModel copyWith({
    String? id,
    String? name,
    String? brand,
    String? category,
    String? imageUrl,
    DateTime? lastUpdated,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'brand': brand,
      'category': category,
      'imageUrl': imageUrl,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'] as String,
      name: map['name'] as String,
      brand: map['brand'] as String,
      category: map['category'] as String,
      imageUrl: map['imageUrl'] as String?,
      lastUpdated: DateTime.parse(map['lastUpdated'] as String),
    );
  }
}
