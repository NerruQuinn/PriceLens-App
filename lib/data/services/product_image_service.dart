import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class ProductImageService {
  static const String _cx = '75ecb7580860e4df7';
  static const String _apiKey = 'AIzaSyDWyFswHqyqVo-J-F7E83-5cCRFGAjMgwk';

  static Future<String?> getProductImage(String productName, {String? barcode}) async {
    debugPrint('[ProductImageService] Starting fetch for: $productName');
    
    final cacheKey = (barcode != null && barcode.isNotEmpty && barcode != 'null')
        ? barcode
        : productName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');

    // 1. Cek cache Firestore dulu
    try {
      final cached = await FirebaseFirestore.instance
          .collection('product_images')
          .doc(cacheKey)
          .get();
      if (cached.exists && cached.data()?['image_url'] != null) {
        debugPrint('[ProductImageService] Cache hit!');
        return cached.data()!['image_url'] as String;
      }
    } catch (e) {
      debugPrint('[ProductImageService] Cache error: $e');
    }

    // 2. Fetch dari Google Custom Search
    try {
      final query = Uri.encodeComponent('$productName');
      final url = 'https://www.googleapis.com/customsearch/v1?key=$_apiKey&cx=$_cx&q=$query&searchType=image&num=1&imgSize=medium&imgType=photo';
      
      debugPrint('[ProductImageService] Fetching: $url');
      final response = await http.get(Uri.parse(url));
      debugPrint('[ProductImageService] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List?;
        if (items != null && items.isNotEmpty) {
          final imageUrl = items[0]['link'] as String?;
          debugPrint('[ProductImageService] Got URL: $imageUrl');
          if (imageUrl != null) {
            // 3. Simpan ke cache Firestore
            try {
              await FirebaseFirestore.instance
                  .collection('product_images')
                  .doc(cacheKey)
                  .set({'image_url': imageUrl, 'cached_at': FieldValue.serverTimestamp()});
            } catch (e) {
              debugPrint('[ProductImageService] Cache save error: $e');
            }
            return imageUrl;
          }
        }
      } else {
        debugPrint('[ProductImageService] Error body: ${response.body.substring(0, 200)}');
      }
    } catch (e) {
      debugPrint('[ProductImageService] Exception: $e');
    }
    return null;
  }
}
