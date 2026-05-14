import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/basket_model.dart';
import 'user_provider.dart';

final currentBasketProvider = StateProvider<BasketModel?>((ref) {
  return null;
});

final basketHistoryProvider = FutureProvider.family<List<BasketModel>, String>((ref, userId) async {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return await firestoreService.getUserBaskets(userId);
});

final basketLoadingProvider = StateProvider<bool>((ref) {
  return false;
});
