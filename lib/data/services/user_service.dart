import 'package:cloud_firestore/cloud_firestore.dart';

final Map<String, String> _displayNameCache = {};

class UserService {
  Future<String> getDisplayName(String userId) async {
    if (_displayNameCache.containsKey(userId)) return _displayNameCache[userId]!;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final name = doc.data()?['displayName'] as String? ?? 'Pengguna PriceLens';
      _displayNameCache[userId] = name;
      return name;
    } catch (e) {
      return 'Pengguna PriceLens';
    }
  }
}
