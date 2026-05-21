import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class SkinSeedService {
  static Future<void> seedSkins() async {
    debugPrint('[SkinSeed] Starting seed...');
    final firestore = FirebaseFirestore.instance;
    final skinsRef = firestore.collection('skins');
    
    final existing = await skinsRef.limit(1).get();
    if (existing.docs.isNotEmpty) {
      debugPrint('[SkinSeed] Skins already seeded, skipping...');
      return; // sudah ada, skip
    }
    
    await _performSeed(firestore, skinsRef);
  }

  static Future<void> forceSeedSkins() async {
    debugPrint('[SkinSeed] Forcing seed...');
    final firestore = FirebaseFirestore.instance;
    final skinsRef = firestore.collection('skins');
    
    await _performSeed(firestore, skinsRef);
  }

  static Future<void> _performSeed(FirebaseFirestore firestore, CollectionReference skinsRef) async {
    final List<Map<String, dynamic>> skins = [
      {'id': 'default', 'name': 'Default Card', 'point_cost': 0, 'type': 'card', 'rarity': 'common', 'preview_url': ''},
      {'id': 'ocean_blue', 'name': 'Ocean Blue', 'point_cost': 50, 'type': 'card', 'rarity': 'common', 'preview_url': ''},
      {'id': 'sunset_orange', 'name': 'Sunset Orange', 'point_cost': 100, 'type': 'card', 'rarity': 'rare', 'preview_url': ''},
      {'id': 'cyber_punk', 'name': 'Cyber Punk', 'point_cost': 200, 'type': 'card', 'rarity': 'rare', 'preview_url': ''},
      {'id': 'gold_legend', 'name': 'Gold Legend', 'point_cost': 500, 'type': 'card', 'rarity': 'epic', 'preview_url': ''},
      {'id': 'dark_mode', 'name': 'Dark Mode', 'pointCost': 150, 'type': 'theme', 'rarity': 'rare', 'preview_url': ''},
      {'id': 'neon_frame', 'name': 'Neon Frame', 'point_cost': 75, 'type': 'avatar_frame', 'rarity': 'common', 'preview_url': ''},
      {'id': 'diamond_frame', 'name': 'Diamond Frame', 'point_cost': 300, 'type': 'avatar_frame', 'rarity': 'epic', 'preview_url': ''},
    ];
    
    final batch = firestore.batch();
    for (final skin in skins) {
      batch.set(skinsRef.doc(skin['id']), skin);
    }
    await batch.commit();
    debugPrint('[SkinSeed] Done!');
  }
}
