import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/product_model.dart';
import '../models/price_entry_model.dart';
import '../models/submission_model.dart';
import '../models/basket_model.dart';
import '../models/skin_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 2. USER METHODS
  Future<UserModel?> getUser(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!);
      }
    } catch (e) {
      debugPrint('Error getUser: \$e');
    }
    return null;
  }

  Future<void> updateUser(UserModel user) async {
    try {
      await _db.collection('users').doc(user.id).update(user.toMap());
    } catch (e) {
      debugPrint('Error updateUser: \$e');
    }
  }

  Future<void> addPoints(String userId, int points) async {
    try {
      await _db.collection('users').doc(userId).update({
        'points': FieldValue.increment(points),
      });
    } catch (e) {
      debugPrint('Error addPoints: \$e');
    }
  }

  Future<void> unlockSkin(String userId, String skinId) async {
    try {
      await _db.collection('users').doc(userId).update({
        'unlockedSkins': FieldValue.arrayUnion([skinId])
      });
    } catch (e) {
      debugPrint('Error unlockSkin: \$e');
    }
  }

  Future<void> setActiveSkin(String userId, String skinId) async {
    try {
      await _db.collection('users').doc(userId).update({
        'currentSkin': skinId,
      });
    } catch (e) {
      debugPrint('Error setActiveSkin: \$e');
    }
  }

  // 3. PRODUCT METHODS
  Future<ProductModel?> getProduct(String productId) async {
    try {
      final doc = await _db.collection('products').doc(productId).get();
      if (doc.exists && doc.data() != null) {
        return ProductModel.fromMap(doc.data()!);
      }
    } catch (e) {
      debugPrint('Error getProduct: \$e');
    }
    return null;
  }

  Future<void> saveProduct(ProductModel product) async {
    try {
      await _db.collection('products').doc(product.id).set(product.toMap());
    } catch (e) {
      debugPrint('Error saveProduct: \$e');
    }
  }

  // 4. PRICE HISTORY METHODS
  Future<List<PriceEntryModel>> getPriceHistory(String productId) async {
    try {
      final snapshot = await _db
          .collection('products')
          .doc(productId)
          .collection('price_history')
          .orderBy('timestamp', descending: true)
          .get();
      return snapshot.docs.map((doc) => PriceEntryModel.fromMap(doc.data())).toList();
    } catch (e) {
      debugPrint('Error getPriceHistory: \$e');
      return [];
    }
  }

  Future<void> addPriceEntry(String productId, PriceEntryModel entry) async {
    try {
      await _db
          .collection('products')
          .doc(productId)
          .collection('price_history')
          .doc(entry.id)
          .set(entry.toMap());
    } catch (e) {
      debugPrint('Error addPriceEntry: \$e');
    }
  }

  Future<PriceEntryModel?> getLowestPrice(String productId) async {
    try {
      final snapshot = await _db
          .collection('products')
          .doc(productId)
          .collection('price_history')
          .orderBy('price', descending: false)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return PriceEntryModel.fromMap(snapshot.docs.first.data());
      }
    } catch (e) {
      debugPrint('Error getLowestPrice: \$e');
    }
    return null;
  }

  // 5. SUBMISSION METHODS
  Future<void> createSubmission(SubmissionModel submission) async {
    try {
      await _db.collection('submissions').doc(submission.id).set(submission.toMap());
    } catch (e) {
      debugPrint('Error createSubmission: \$e');
    }
  }

  Future<String> submitPrice(Map<String, dynamic> data) async {
    try {
      final docRef = await _db.collection('community_submissions').add({
        'userId': data['userId'],
        'product_id': data['product_id'],
        'product_name': data['product_name'] ?? 'Unknown Product',
        'price': data['price'],
        'store_name': data['store_name'],
        'city': data['city'],
        'photo_url': data['photo_url'],
        'status': data['status'] ?? 'pending',
        'ai_validation_score': data['ai_validation_score'] ?? 0,
        'upvotes': 0,
        'upvoted_by': [],
        'timestamp': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      debugPrint('Error submitPrice: \$e');
      rethrow;
    }
  }

  Future<void> updateSubmissionStatus(String submissionId, String status, double aiScore, String reason) async {
    try {
      await _db.collection('submissions').doc(submissionId).update({
        'status': status,
        'aiValidationScore': aiScore,
        'aiReason': reason,
      });
    } catch (e) {
      debugPrint('Error updateSubmissionStatus: \$e');
    }
  }

  Future<List<SubmissionModel>> getUserSubmissions(String userId) async {
    try {
      final snapshot = await _db
          .collection('submissions')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();
      return snapshot.docs.map((doc) => SubmissionModel.fromMap(doc.data())).toList();
    } catch (e) {
      debugPrint('Error getUserSubmissions: \$e');
      return [];
    }
  }

  Future<void> upvoteSubmission(String submissionId, String userId) async {
    try {
      await _db.collection('submissions').doc(submissionId).update({
        'upvotes': FieldValue.increment(1),
        'upvotedBy': FieldValue.arrayUnion([userId])
      });
    } catch (e) {
      debugPrint('Error upvoteSubmission: \$e');
    }
  }

  Stream<List<SubmissionModel>> getRecentSubmissions(int limit) {
    try {
      return _db
          .collection('submissions')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) =>
              snapshot.docs.map((doc) => SubmissionModel.fromMap(doc.data())).toList());
    } catch (e) {
      debugPrint('Error getRecentSubmissions: \$e');
      return Stream.value([]);
    }
  }

  // 6. BASKET METHODS
  Future<void> saveBasket(BasketModel basket) async {
    try {
      await _db.collection('baskets').doc(basket.id).set(basket.toMap());
    } catch (e) {
      debugPrint('Error saveBasket: \$e');
    }
  }

  Future<List<BasketModel>> getUserBaskets(String userId) async {
    try {
      final snapshot = await _db
          .collection('baskets')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => BasketModel.fromMap(doc.data())).toList();
    } catch (e) {
      debugPrint('Error getUserBaskets: \$e');
      return [];
    }
  }

  // 7. SKIN METHODS
  Future<List<SkinModel>> getAllSkins() async {
    try {
      final snapshot = await _db.collection('skins').get();
      return snapshot.docs.map((doc) => SkinModel.fromMap(doc.data())).toList();
    } catch (e) {
      debugPrint('Error getAllSkins: \$e');
      return [];
    }
  }

  Future<SkinModel?> getSkin(String skinId) async {
    try {
      final doc = await _db.collection('skins').doc(skinId).get();
      if (doc.exists && doc.data() != null) {
        return SkinModel.fromMap(doc.data()!);
      }
    } catch (e) {
      debugPrint('Error getSkin: \$e');
    }
    return null;
  }

  // 8. PROMO CACHE METHODS
  Future<Map<String, dynamic>?> getPromoCache(String productId) async {
    try {
      final doc = await _db.collection('promo_cache').doc(productId).get();
      if (doc.exists && doc.data() != null) {
        return doc.data();
      }
    } catch (e) {
      debugPrint('Error getPromoCache: \$e');
    }
    return null;
  }

  Future<void> setPromoCache(String productId, Map<String, dynamic> data) async {
    try {
      await _db.collection('promo_cache').doc(productId).set(data);
    } catch (e) {
      debugPrint('Error setPromoCache: \$e');
    }
  }
}
