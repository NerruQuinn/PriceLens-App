class ProductImageService {
  static Future<String?> getProductImage(String productName, {String? barcode}) async {
    // Temporary disable all HTTP requests to Google Custom Search API
    // until billing setup is completed.
    return null;
  }
}
