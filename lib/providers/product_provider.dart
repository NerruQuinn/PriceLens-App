import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/product_model.dart';
import '../data/models/price_entry_model.dart';
import 'user_provider.dart';

final currentProductProvider = StateProvider<ProductModel?>((ref) {
  return null;
});

final priceHistoryProvider = FutureProvider.family<List<PriceEntryModel>, String>((ref, productId) async {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return await firestoreService.getPriceHistory(productId);
});

final isLoadingProvider = StateProvider<bool>((ref) {
  return false;
});
