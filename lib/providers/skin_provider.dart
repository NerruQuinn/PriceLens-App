import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/skin_model.dart';
import 'user_provider.dart';

final allSkinsProvider = FutureProvider<List<SkinModel>>((ref) async {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return await firestoreService.getAllSkins();
});

final selectedSkinProvider = StateProvider<SkinModel?>((ref) {
  return null;
});
