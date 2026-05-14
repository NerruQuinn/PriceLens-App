import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  Future<String?> uploadReceiptPhoto(Uint8List imageBytes, String userId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uuidStr = _uuid.v4();
      final path = 'receipts/\$userId/\${timestamp}_\$uuidStr.jpg';
      final ref = _storage.ref().child(path);
      
      final uploadTask = await ref.putData(imageBytes, SettableMetadata(contentType: 'image/jpeg'));
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploadReceiptPhoto: \$e');
      return null;
    }
  }

  Future<String?> uploadProductPhoto(Uint8List imageBytes, String productId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = 'products/\$productId/\$timestamp.jpg';
      final ref = _storage.ref().child(path);
      
      final uploadTask = await ref.putData(imageBytes, SettableMetadata(contentType: 'image/jpeg'));
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploadProductPhoto: \$e');
      return null;
    }
  }

  Future<String?> uploadBasketPhoto(Uint8List imageBytes, String userId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = 'baskets/\$userId/\$timestamp.jpg';
      final ref = _storage.ref().child(path);
      
      final uploadTask = await ref.putData(imageBytes, SettableMetadata(contentType: 'image/jpeg'));
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploadBasketPhoto: \$e');
      return null;
    }
  }

  Future<void> deletePhoto(String photoUrl) async {
    try {
      final ref = _storage.refFromURL(photoUrl);
      await ref.delete();
    } catch (e) {
      debugPrint('Error deletePhoto: \$e');
    }
  }
}
