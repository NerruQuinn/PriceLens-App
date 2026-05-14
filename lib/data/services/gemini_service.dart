import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  late GenerativeModel _model;

  GeminiService() {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not found in .env');
    }
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
    );
  }

  Future<Map<String, dynamic>?> analyzeSingleProduct(Uint8List imageBytes) async {
    try {
      final prompt = TextPart("\${GeminiPrompts.systemInstructionSingleProduct}\n\nTolong analisis gambar produk ini dan berikan output dalam format JSON sesuai instruksi.");
      final imagePart = DataPart('image/jpeg', imageBytes);
      
      final response = await _model.generateContent([
        Content.multi([prompt, imagePart])
      ]);

      if (response.text != null) {
        final text = response.text!.replaceAll(RegExp(r'```json\n|```\n|```'), '').trim();
        return jsonDecode(text) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error analyzeSingleProduct: \$e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> analyzeBasket(Uint8List imageBytes) async {
    try {
      final prompt = TextPart("\${GeminiPrompts.systemInstructionBasket}\n\nTolong analisis gambar keranjang belanja/struk ini dan berikan output dalam format JSON sesuai instruksi.");
      final imagePart = DataPart('image/jpeg', imageBytes);
      
      final response = await _model.generateContent([
        Content.multi([prompt, imagePart])
      ]);

      if (response.text != null) {
        final text = response.text!.replaceAll(RegExp(r'```json\n|```\n|```'), '').trim();
        return jsonDecode(text) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error analyzeBasket: \$e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> validateSubmission({
    required String productName,
    required double submittedPrice,
    required String storeName,
    Uint8List? receiptImage,
  }) async {
    try {
      final prompt = TextPart("\${GeminiPrompts.systemInstructionValidator}\n\nTolong validasi laporan harga berikut:\nNama Produk: \$productName\nHarga Dilaporkan: Rp\$submittedPrice\nToko: \$storeName\n\nBerikan output dalam format JSON sesuai instruksi.");
      
      final List<Part> parts = [prompt];
      if (receiptImage != null) {
        parts.add(DataPart('image/jpeg', receiptImage));
      }

      final response = await _model.generateContent([
        Content.multi(parts)
      ]);

      if (response.text != null) {
        final text = response.text!.replaceAll(RegExp(r'```json\n|```\n|```'), '').trim();
        return jsonDecode(text) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error validateSubmission: \$e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> analyzeProductFromBarcode(String barcode) async {
    try {
      final prompt = TextPart("\${GeminiPrompts.systemInstructionSingleProduct}\n\nCari informasi produk dengan barcode/GTIN: \$barcode di pasar Indonesia. Berikan nama produk, merek, kategori, dan harga terkini di berbagai toko online dan offline Indonesia dalam format JSON sesuai instruksi.");
      
      final response = await _model.generateContent([
        Content.text(prompt.text)
      ]);

      if (response.text != null) {
        final text = response.text!.replaceAll(RegExp(r'```json\n|```\n|```'), '').trim();
        return jsonDecode(text) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error analyzeProductFromBarcode: \$e');
    }
    return null;
  }
}
