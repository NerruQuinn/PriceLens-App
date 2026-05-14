import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/services/firestore_service.dart';
import '../data/models/user_model.dart';

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

final userProvider = FutureProvider.family<UserModel?, String>((ref, userId) async {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return await firestoreService.getUser(userId);
});

final userPointsProvider = StateProvider<int>((ref) {
  return 0;
});

final activeSkinProvider = StateProvider<String>((ref) {
  return "default";
});
