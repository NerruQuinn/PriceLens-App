double _parsePrice(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  if (value is String) {
    String cleaned = value.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned) ?? 0;
  }
  if (value is Map) {
    return _parsePrice(value['value'] ?? value['amount'] ?? value['price'] ?? 0);
  }
  return 0;
}

class BasketModel {
  final String id;
  final String userId;
  final List<BasketItemModel> items;
  final double totalEstimate;
  final String? photoUrl;
  final DateTime createdAt;
  final double savingsPotential;
  final String savingsTip;

  BasketModel({
    required this.id,
    required this.userId,
    required this.items,
    required this.totalEstimate,
    this.photoUrl,
    required this.createdAt,
    this.savingsPotential = 0.0,
    this.savingsTip = '',
  });

  BasketModel copyWith({
    String? id,
    String? userId,
    List<BasketItemModel>? items,
    double? totalEstimate,
    String? photoUrl,
    DateTime? createdAt,
    double? savingsPotential,
    String? savingsTip,
  }) {
    return BasketModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      items: items ?? this.items,
      totalEstimate: totalEstimate ?? this.totalEstimate,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      savingsPotential: savingsPotential ?? this.savingsPotential,
      savingsTip: savingsTip ?? this.savingsTip,
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
      'savingsPotential': savingsPotential,
      'savingsTip': savingsTip,
    };
  }

  factory BasketModel.fromMap(Map<String, dynamic> map) {
    double totalEstimate = map.containsKey('totalEstimate') 
        ? _parsePrice(map['totalEstimate'])
        : _parsePrice((map['summary'] as Map?)?['total_estimate']);
        
    if (totalEstimate == 0.0) {
      final items = map['items'] as List? ?? [];
      totalEstimate = items.fold(0.0, (sum, item) => sum + _parsePrice(item is Map ? item['subtotal'] : null));
    }

    return BasketModel(
      id: map['id'] as String,
      userId: map['userId'] as String,
      items: (map['items'] as List<dynamic>?)
              ?.map((item) => BasketItemModel.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      totalEstimate: totalEstimate,
      photoUrl: map['photoUrl'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String? ?? DateTime.now().toIso8601String()),
      savingsPotential: map.containsKey('savingsPotential')
          ? _parsePrice(map['savingsPotential'])
          : _parsePrice((map['summary'] as Map?)?['potential_savings']),
      savingsTip: map['savingsTip'] as String? ?? ((map['summary'] as Map?)?['savings_tip'] as String?) ?? '',
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
      name: map['name'] as String? ?? 'Unknown Item',
      brand: map['brand'] as String?,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      unitPriceEstimate: map.containsKey('unit_price_estimate') 
          ? _parsePrice(map['unit_price_estimate'])
          : _parsePrice(map['unitPriceEstimate']),
      subtotal: _parsePrice(map['subtotal']),
      confidence: map['confidence']?.toString() ?? 'medium',
      cheapestStore: map['cheapest_store']?.toString() ?? map['cheapestStore']?.toString() ?? '',
    );
  }
}
