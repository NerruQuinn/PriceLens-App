import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiService {
  static List<String> _apiKeys = [
    dotenv.env['GEMINI_API_KEY_1'] ?? '',
    dotenv.env['GEMINI_API_KEY_2'] ?? '',
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

  Future<Map<String, dynamic>?> getPromoData() async {
    try {
      final model = _getModel();
      const promptText =
          'Kamu adalah asisten belanja Indonesia. Berikan perkiraan harga wajar 5 produk sembako umum '
          'di minimarket Indonesia (Indomaret/Alfamart) berdasarkan harga pasar yang realistis tahun 2024-2025: '
          'beras premium 5kg, minyak goreng 2L, gula pasir 1kg, telur ayam 1kg, susu UHT 1L. '
          'Gunakan harga yang benar-benar realistis, misalnya beras 5kg sekitar Rp 70.000-85.000, '
          'minyak goreng 2L sekitar Rp 28.000-35.000, gula 1kg sekitar Rp 17.000-19.000, '
          'telur 1kg sekitar Rp 28.000-32.000, susu UHT 1L sekitar Rp 18.000-24.000. '
          'Return ONLY strict JSON no markdown: '
          '{"promos":[{"name":"...","store":"Indomaret atau Alfamart","original_price":0,"discount_price":0,"discount_percent":0,"category":"Sembako"}],'
          '"trending":[{"name":"...","store":"...","price":0,"category":"..."}]}. '
          'discount_price sama dengan original_price, discount_percent isi 0.';

      final response = await model.generateContent([Content.text(promptText)]);
      final content = response.text;
      if (content == null) return null;

      final clean = content
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();

      final jsonStart = clean.indexOf('{');
      final jsonEnd = clean.lastIndexOf('}');
      if (jsonStart == -1 || jsonEnd == -1) return null;

      return jsonDecode(clean.substring(jsonStart, jsonEnd + 1)) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[GeminiService] getPromoData exception: $e');
      return null;
    }
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
          'IMPORTANT: Always respond in Bahasa Indonesia. '
          'Kamu adalah PriceLens ID, asisten perbandingan harga pasar Indonesia. '
          'Analisis gambar produk ini dan berikan perkiraan harga yang realistis di pasar Indonesia 2024-2025. '
          'Sertakan harga dari Alfamart, Indomaret, dan marketplace online (Tokopedia, Shopee). '
          'Return ONLY strict JSON no markdown: '
          '{product:{name,brand,category,barcode},'
          'prices:[{store,price,type,is_official_store,discount_percent,original_price,source_url}],'
          'market_summary:{lowest_price,highest_price,average_price,recommendation},'
          'smart_advisor:string}.');

      final response = await model.generateContent([
        Content.multi([prompt, imagePart])
      ]);

      final content = response.text;
      if (content == null) return null;

      final clean = content.replaceAll('```json', '').replaceAll('```', '').trim();
      final jsonStart = clean.indexOf('{');
      final jsonEnd = clean.lastIndexOf('}');
      if (jsonStart == -1 || jsonEnd == -1) return null;

      return jsonDecode(clean.substring(jsonStart, jsonEnd + 1)) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[GeminiService] analyzeProduct exception: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> analyzeSingleProduct(dynamic imageFile) async {
    return analyzeProduct(imageFile);
  }

  Future<Map<String, dynamic>?> analyzeProductFromBarcode(String barcode) async {
    try {
      final model = _getModel();
      final prompt = TextPart(
          'IMPORTANT: Always respond in Bahasa Indonesia. '
          'Kamu adalah PriceLens ID, asisten perbandingan harga pasar Indonesia. '
          'Cari produk "$barcode" dan berikan perkiraan harga yang realistis di pasar Indonesia 2024-2025. '
          'Sertakan harga dari Alfamart, Indomaret, dan marketplace online. '
          'Return ONLY strict JSON no markdown: '
          '{product:{name,brand,category,barcode},'
          'prices:[{store,price,type,is_official_store,discount_percent,original_price,source_url}],'
          'market_summary:{lowest_price,highest_price,average_price,recommendation},'
          'smart_advisor:string}.');

      final response = await model.generateContent([Content.text(prompt.text)]);

      final content = response.text;
      if (content == null) return null;

      final clean = content.replaceAll('```json', '').replaceAll('```', '').trim();
      final jsonStart = clean.indexOf('{');
      final jsonEnd = clean.lastIndexOf('}');
      if (jsonStart == -1 || jsonEnd == -1) return null;

      return jsonDecode(clean.substring(jsonStart, jsonEnd + 1)) as Map<String, dynamic>;
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
          'IMPORTANT: Always respond in Bahasa Indonesia. '
          'Kamu adalah asisten belanja. Identifikasi semua produk dalam gambar ini dan '
          'berikan estimasi harga realistis di pasar Indonesia 2024-2025. '
          'Return JSON: {items:[{name,brand,quantity,unit_price_estimate,subtotal,confidence,cheapest_store}],'
          'summary:{total_items,total_estimate,potential_savings,savings_tip}}');

      final response = await model.generateContent([
        Content.multi([prompt, imagePart])
      ]);

      final content = response.text;
      if (content == null) return null;

      final clean = content.replaceAll('```json', '').replaceAll('```', '').trim();
      final jsonStart = clean.indexOf('{');
      final jsonEnd = clean.lastIndexOf('}');
      if (jsonStart == -1 || jsonEnd == -1) return null;

      return jsonDecode(clean.substring(jsonStart, jsonEnd + 1)) as Map<String, dynamic>;
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
          'Kamu adalah AI validator harga pasar Indonesia. '
          'Validasi apakah harga Rp $submittedPrice untuk produk "$productName" di "$storeName" wajar '
          'berdasarkan harga pasar Indonesia 2024-2025. '
          'Return ONLY strict JSON no markdown: '
          '{validation:{status,confidence_score,market_median_price,price_deviation_percent,is_store_valid},'
          'reason:string,points_awarded:number}';

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
          Content.multi([TextPart(promptText), imagePart])
        ]);
      } else {
        response = await model.generateContent([Content.text(promptText)]);
      }

      final content = response.text;
      if (content == null) return null;

      final clean = content.replaceAll('```json', '').replaceAll('```', '').trim();
      final jsonStart = clean.indexOf('{');
      final jsonEnd = clean.lastIndexOf('}');
      if (jsonStart == -1 || jsonEnd == -1) return null;

      return jsonDecode(clean.substring(jsonStart, jsonEnd + 1)) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[GeminiService] validateSubmission exception: $e');
      return null;
    }
  }
}
