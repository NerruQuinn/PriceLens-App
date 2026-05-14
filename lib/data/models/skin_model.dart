import 'package:flutter/material.dart';

class SkinModel {
  final String id;
  final String name;
  final int pointCost;
  final String? previewUrl;
  final String type;
  final String rarity;
  final String category;
  final int price;
  final bool isFeatured;
  final DateTime? featuredDeadline;
  final String? thumbnailUrl;
  final Color previewColor;

  SkinModel({
    required this.id,
    required this.name,
    required this.pointCost,
    this.previewUrl,
    required this.type,
    required this.rarity,
    this.category = 'all',
    int? price,
    this.isFeatured = false,
    this.featuredDeadline,
    this.thumbnailUrl,
    this.previewColor = Colors.blueGrey,
  }) : price = price ?? pointCost;

  SkinModel copyWith({
    String? id,
    String? name,
    int? pointCost,
    String? previewUrl,
    String? type,
    String? rarity,
    String? category,
    int? price,
    bool? isFeatured,
    DateTime? featuredDeadline,
    String? thumbnailUrl,
    Color? previewColor,
  }) {
    return SkinModel(
      id: id ?? this.id,
      name: name ?? this.name,
      pointCost: pointCost ?? this.pointCost,
      previewUrl: previewUrl ?? this.previewUrl,
      type: type ?? this.type,
      rarity: rarity ?? this.rarity,
      category: category ?? this.category,
      price: price ?? this.price,
      isFeatured: isFeatured ?? this.isFeatured,
      featuredDeadline: featuredDeadline ?? this.featuredDeadline,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      previewColor: previewColor ?? this.previewColor,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'pointCost': pointCost,
      'previewUrl': previewUrl,
      'type': type,
      'rarity': rarity,
      'category': category,
      'price': price,
      'isFeatured': isFeatured,
      'featuredDeadline': featuredDeadline?.toIso8601String(),
      'thumbnailUrl': thumbnailUrl,
      'previewColor': previewColor.toARGB32(),
    };
  }

  factory SkinModel.fromMap(Map<String, dynamic> map) {
    return SkinModel(
      id: map['id'] as String,
      name: map['name'] as String,
      pointCost: (map['pointCost'] as num?)?.toInt() ?? 0,
      previewUrl: map['previewUrl'] as String?,
      type: map['type'] as String? ?? 'card_design',
      rarity: map['rarity'] as String? ?? 'common',
      category: map['category'] as String? ?? 'all',
      price: (map['price'] as num?)?.toInt() ?? (map['pointCost'] as num?)?.toInt() ?? 0,
      isFeatured: map['isFeatured'] as bool? ?? false,
      featuredDeadline: map['featuredDeadline'] != null
          ? DateTime.tryParse(map['featuredDeadline'] as String)
          : null,
      thumbnailUrl: map['thumbnailUrl'] as String?,
      previewColor: map['previewColor'] != null
          ? Color(map['previewColor'] as int)
          : Colors.blueGrey,
    );
  }
}
