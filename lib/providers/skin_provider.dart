import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_provider.dart';
import '../data/models/skin_model.dart';

final activeSkinProvider = StreamProvider<String>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value('default');
  return FirebaseFirestore.instance
    .collection('users')
    .doc(user.uid)
    .snapshots()
    .map((doc) {
      final skin = doc.data()?['current_skin'] as String? ?? 'default';
      debugPrint('[SkinProvider] Active skin: $skin');
      return skin;
    });
});

final allSkinsProvider = FutureProvider<List<SkinModel>>((ref) async {
  final snapshot = await FirebaseFirestore.instance.collection('skins').get();
  return snapshot.docs.map((doc) {
    final data = doc.data();
    data['id'] = doc.id;
    return SkinModel.fromMap(data);
  }).toList();
});
