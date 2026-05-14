import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/submission_model.dart';
import 'user_provider.dart';

final recentSubmissionsProvider = StreamProvider<List<SubmissionModel>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getRecentSubmissions(20);
});

final userSubmissionsProvider = FutureProvider.family<List<SubmissionModel>, String>((ref, userId) async {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return await firestoreService.getUserSubmissions(userId);
});

final submissionLoadingProvider = StateProvider<bool>((ref) {
  return false;
});
