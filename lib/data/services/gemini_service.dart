import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  static const List<String> _apiKeys = [
    'AIzaSyDWyFswHqyqVo-J-F7E83-5cCRFGAjMgwk',
    'AIzaSyBxsRIoLjz8hJsgPbPzGm1hZ2kP-BfUoqU',
    'AIzaSyAGoai8Wv0_o9gp8pWfna_gqs2VGsXYl1Y'
  ];

  static int _currentKeyIndex = 0;

  static String get _currentApiKey {
    final key = _apiKeys[_currentKeyIndex];
    _currentKeyIndex = (_currentKeyIndex + 1) % _apiKeys.length;
    return key;
  }

  GenerativeModel _getModel() {
    return GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _currentApiKey,
    );
  }

  Future<Map<String, dynamic>?> analyzeProduct(dynamic imageFile) async {
    try {
      final model = _getModel();

      Uint8List bytes;
      if (imageFile is File) {
        bytes = await imageFile.readAsBytes();
      } else if (imageFile is Uint8List) {
        bytes = imageFile;
      } else {
        return null;
      }

      final imagePart = DataPart('image/jpeg', bytes);
      final prompt = TextPart(
          "You are PriceLens ID, an AI price comparison assistant for Indonesian market. Analyze the product image and return ONLY strict JSON no markdown: {product:{name,brand,category,barcode},prices:[{store,price,type,is_official_store,discount_percent,original_price,source_url}],market_summary:{lowest_price,highest_price,average_price,recommendation},smart_advisor:string}. For each price entry, include a source_url field with the actual product listing URL from that store if available, otherwise leave null");

      final response = await model.generateContent([
        Content.multi([prompt, imagePart])
      ]);

      final content = response.text;
      if (content == null) return null;

      final cleanResponse =
          content.replaceAll('```json', '').replaceAll('```', '').trim();
      return jsonDecode(cleanResponse) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[GeminiService] analyzeProduct exception: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getPromoData() async {
    try {
      final model = _getModel();

      const promptText =
          'Kamu adalah asisten belanja Indonesia. Buat daftar promo dan diskon produk sembako terlaris '
          'di Indomaret dan Alfamart hari ini berdasarkan pengetahuanmu. '
          'Return ONLY strict JSON no markdown: '
          '{"promos":[{"name":"...","store":"...","original_price":0,"discount_price":0,"discount_percent":0,"category":"..."}],'
          '"trending":[{"name":"...","store":"...","price":0,"category":"..."}]}';

      final response = await model.generateContent([Content.text(promptText)]);

      final content = response.text;
      if (content == null) return null;

      // Strip markdown code fences
      final clean = content
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();

      return jsonDecode(clean) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[GeminiService] getPromoData exception: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> analyzeSingleProduct(dynamic imageFile) async {
    return analyzeProduct(imageFile);
  }

  Future<Map<String, dynamic>?> analyzeProductFromBarcode(
      String barcode) async {
    try {
      final model = _getModel();

      final prompt = TextPart(
          "You are PriceLens ID, an AI price comparison assistant for Indonesian market. Analyze this product based on barcode ($barcode) and return ONLY strict JSON no markdown: {product:{name,brand,category,barcode},prices:[{store,price,type,is_official_store,discount_percent,original_price,source_url}],market_summary:{lowest_price,highest_price,average_price,recommendation},smart_advisor:string}. For each price entry, include a source_url field with the actual product listing URL from that store if available, otherwise leave null");

      final response = await model.generateContent([Content.text(prompt.text)]);

      final content = response.text;
      if (content == null) return null;

      final cleanResponse =
          content.replaceAll('```json', '').replaceAll('```', '').trim();
      return jsonDecode(cleanResponse) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[GeminiService] analyzeProductFromBarcode exception: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> analyzeBasket(dynamic imageFile) async {
    try {
      final model = _getModel();

      Uint8List bytes;
      if (imageFile is File) {
        bytes = await imageFile.readAsBytes();
      } else if (imageFile is Uint8List) {
        bytes = imageFile;
      } else {
        return null;
      }

      final imagePart = DataPart('image/jpeg', bytes);
      final prompt = TextPart(
          "You are a helpful shopping assistant. Please identify all grocery/shopping items in this image and provide price estimates for each item in Indonesia. Return JSON format: {items:[{name,brand,quantity,unit_price_estimate,subtotal,confidence,cheapest_store}],summary:{total_items,total_estimate,potential_savings,savings_tip}}");

      final response = await model.generateContent([
        Content.multi([prompt, imagePart])
      ]);

      final content = response.text;
      if (content == null) return null;

      debugPrint('[GeminiService] Raw response: $content');

      final cleanResponse =
          content.replaceAll('```json', '').replaceAll('```', '').trim();
      return jsonDecode(cleanResponse) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[GeminiService] analyzeBasket exception: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> validateSubmission({
    required String productName,
    required num submittedPrice,
    required String storeName,
    dynamic receiptImage,
  }) async {
    try {
      final model = _getModel();

      final promptText =
          "You are a price validation AI for Indonesian market. Validate this price submission: Product: $productName, Price: Rp $submittedPrice, Store: $storeName. Return ONLY strict JSON no markdown: {validation:{status,confidence_score,market_median_price,price_deviation_percent,is_store_valid},reason:string,points_awarded:number}";
      final prompt = TextPart(promptText);

      Uint8List? bytes;
      if (receiptImage is File) {
        bytes = await receiptImage.readAsBytes();
      } else if (receiptImage is Uint8List) {
        bytes = receiptImage;
      }

      GenerateContentResponse response;
      if (bytes != null) {
        final imagePart = DataPart('image/jpeg', bytes);
        response = await model.generateContent([
          Content.multi([prompt, imagePart])
        ]);
      } else {
        response = await model.generateContent([Content.text(prompt.text)]);
      }

      final content = response.text;
      if (content == null) return null;

      final cleanResponse =
          content.replaceAll('```json', '').replaceAll('```', '').trim();
      return jsonDecode(cleanResponse) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[GeminiService] validateSubmission exception: $e');
      return null;
    }
  }
}
