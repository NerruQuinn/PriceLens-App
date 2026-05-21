import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/models/product_model.dart';

import '../../../data/services/gemini_service.dart';
import '../../../data/services/product_image_service.dart';
import '../../../providers/user_provider.dart';
import '../../../providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PriceResultScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? extra;

  const PriceResultScreen({super.key, this.extra});

  @override
  ConsumerState<PriceResultScreen> createState() => _PriceResultScreenState();
}

class _PriceResultScreenState extends ConsumerState<PriceResultScreen> {
  Map<String, dynamic>? _resultData;
  bool _isLoading = true;
  String? _errorMessage;
  Uint8List? imageBytes;
  String? barcode;
  String type = 'product';
  String? _fetchedImageUrl;

  @override
  void initState() {
    super.initState();
    
    if (widget.extra == null) {
      _isLoading = false;
      _errorMessage = "Data tidak tersedia";
      return;
    }

    imageBytes = widget.extra!['imageBytes'] as Uint8List?;
    barcode = widget.extra!['barcode'] as String?;
    type = widget.extra!['type'] as String? ?? 'product';
    _resultData = widget.extra!['data'] as Map<String, dynamic>?;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_resultData != null) {
        setState(() {
          _isLoading = false;
        });
        
        final productName = _resultData!['product']?['name'] ?? '';
        final barcodeStr = _resultData!['product']?['barcode']?.toString() ?? barcode;
        ProductImageService.getProductImage(productName, barcode: barcodeStr).then((url) {
          debugPrint('[ProductImageService] Got URL: $url');
          if (mounted && url != null) {
            setState(() => _fetchedImageUrl = url);
          }
        });

        _saveToFirestore(_resultData!);
      } else {
        _analyzeProduct();
      }
    });
  }

  Future<void> _launchURL(String storeName, String productName) async {
    final query = Uri.encodeComponent('$productName $storeName harga Indonesia');
    final urlString = 'https://www.google.com/search?q=$query';
    debugPrint('[SourceLink] Opening: $urlString');
    final uri = Uri.parse(urlString);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[SourceLink] Error: $e');
    }
  }

  Future<void> _saveToFirestore(Map<String, dynamic> result) async {
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final product = ProductModel(
        id: result['product']?['barcode']?.toString() ?? barcode ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: result['product']?['name'] ?? 'Unknown Product',
        brand: result['product']?['brand'] ?? 'Unknown Brand',
        category: result['product']?['category'] ?? 'General',
        imageUrl: result['image_url'],
        lastUpdated: DateTime.now(),
      );
      await firestoreService.saveProduct(product);
    } catch (e) {
      debugPrint('Error saving to Firestore: \$e');
    }
  }

  Future<void> _analyzeProduct() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final geminiService = GeminiService();

      Map<String, dynamic>? result;
      if (type == 'barcode' && barcode != null) {
        result = await geminiService.analyzeProductFromBarcode(barcode!);
      } else if (type == 'product' && imageBytes != null) {
        result = await geminiService.analyzeSingleProduct(imageBytes!);
      }

      if (result != null) {
        if (mounted) {
          setState(() {
            _resultData = result;
          });
        }
        
        final productName = result['product']?['name'] ?? '';
        final barcodeStr = result['product']?['barcode']?.toString() ?? barcode;
        ProductImageService.getProductImage(productName, barcode: barcodeStr).then((url) {
          debugPrint('[ProductImageService] Got URL: $url');
          if (mounted && url != null) {
            setState(() => _fetchedImageUrl = url);
          }
        });

        // Simpan ke Firestore via firestoreService jika result tidak null
        await _saveToFirestore(result);
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = "Gagal mendapatkan data produk";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveToWishlist() async {
    if (_resultData == null) return;
    try {
      final user = ref.read(currentUserModelProvider).value;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Harap login terlebih dahulu')),
        );
        return;
      }
      
      final productId = _resultData!['product']?['barcode']?.toString() ?? barcode ?? DateTime.now().millisecondsSinceEpoch.toString();
      final lowestPrice = _resultData!['market_summary']?['lowest_price'] ?? 0;
      
      // Find store that has the lowest price
      final prices = _resultData!['prices'] as List<dynamic>? ?? [];
      String store = 'Toko';
      if (prices.isNotEmpty) {
        final lowestPriceItem = prices.firstWhere(
          (p) => p['price'] == lowestPrice, 
          orElse: () => prices.first
        );
        store = lowestPriceItem['store'] ?? 'Toko';
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .collection('wishlist')
          .doc(productId)
          .set({
        'name': _resultData!['product']?['name'] ?? 'Unknown Product',
        'brand': _resultData!['product']?['brand'] ?? 'Unknown Brand',
        'lowest_price': lowestPrice,
        'store': store,
        'saved_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Berhasil disimpan ke wishlist')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Menganalisis produk...', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Mencari harga terbaik di seluruh Indonesia',
                style: textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null || _resultData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_errorMessage ?? 'Terjadi kesalahan', style: textTheme.titleMedium),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _analyzeProduct,
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    final prices = _resultData!['prices'] as List<dynamic>? ?? [];
    final legitCheck = _resultData!['legit_check'] as Map<String, dynamic>? ?? {};

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // a) SliverAppBar
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeaderImage(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.bookmark_border),
                onPressed: _saveToWishlist,
              ),
            ],
          ),

          // b) PRODUCT INFO
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _resultData!['product']?['name'] ?? 'Unknown Product',
                    style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Chip(label: Text(_resultData!['product']?['brand'] ?? 'Brand')),
                      const SizedBox(width: 8),
                      Chip(label: Text(_resultData!['product']?['category'] ?? 'Category')),
                    ],
                  ),
                  const Divider(height: 32),
                ],
              ),
            ),
          ),

          // c) SMART ADVISOR CARD
          if (_resultData!['smart_advisor'] != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Card(
                  color: colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.auto_awesome, color: colorScheme.onPrimaryContainer),
                            const SizedBox(width: 8),
                            Text(
                              'Smart Advisor',
                              style: textTheme.titleMedium?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _resultData!['smart_advisor'].toString(),
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        if (_resultData!['market_summary']?['recommendation'] != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _resultData!['market_summary']['recommendation'].toString(),
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // d) PERBANDINGAN HARGA
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
              child: Text(
                'Perbandingan Harga',
                style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: prices.length,
              itemBuilder: (context, index) {
                final priceItem = prices[index];
                final storeName = priceItem['store'] ?? 'Toko';
                final isOfficial = priceItem['is_official_store'] == true;
                final priceDisplay = priceItem['price']?.toString() ?? '0';
                final discount = priceItem['discount_percent']?.toString();
                final typeChip = priceItem['type'] ?? 'online';

                // Find if this is the lowest price
                bool isLowest = priceItem['price'] == _resultData!['market_summary']?['lowest_price'] || index == 0;

                return Card(
                  shape: isOfficial
                      ? RoundedRectangleBorder(
                          side: const BorderSide(color: Colors.green, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        )
                      : null,
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(storeName.isNotEmpty ? storeName[0] : 'S'),
                    ),
                    title: Text(storeName),
                    subtitle: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            typeChip,
                            style: const TextStyle(fontSize: 10, color: Colors.black87),
                          ),
                        ),
                        if (isOfficial) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified, size: 10, color: Colors.green),
                                SizedBox(width: 2),
                                Text(
                                  'Official',
                                  style: TextStyle(fontSize: 10, color: Colors.green),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Rp $priceDisplay',
                              style: TextStyle(
                                color: isLowest ? Colors.green : colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (discount != null && discount.isNotEmpty && discount != '0')
                              Text(
                                '-$discount%',
                                style: const TextStyle(color: Colors.red, fontSize: 12),
                              ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.open_in_new, size: 20),
                          tooltip: 'Lihat Sumber',
                          onPressed: () async {
                            debugPrint('BUTTON TAPPED');
                            final productName = _resultData!['product']?['name'] ?? '';
                            await _launchURL(storeName, productName);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // e) TREN HARGA
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
              child: Text(
                'Tren Harga 7 Hari',
                style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              height: 200,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: const [
                        FlSpot(0, 3),
                        FlSpot(1, 1),
                        FlSpot(2, 4),
                        FlSpot(3, 3),
                        FlSpot(4, 5),
                        FlSpot(5, 3),
                        FlSpot(6, 4),
                      ],
                      isCurved: true,
                      color: colorScheme.primary,
                      barWidth: 3,
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary.withValues(alpha: 0.3),
                            colorScheme.primary.withValues(alpha: 0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // f) LEGIT CHECK
          if (legitCheck['warning'] != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  color: Colors.orange[100],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            legitCheck['warning'].toString(),
                            style: const TextStyle(color: Colors.deepOrange),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // g) COMMUNITY CTA
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 32.0),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: colorScheme.outline),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Menemukan harga berbeda?',
                        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Bantu komunitas & dapatkan +10 poin',
                        style: textTheme.bodyMedium?.copyWith(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.tonal(
                        onPressed: () => context.go('/submit', extra: _resultData),
                        child: const Text('Submit Harga Real Kamu'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _saveToWishlist,
            child: const Text('Simpan ke Wishlist'),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderImage() {
    final imageUrl = _fetchedImageUrl ?? _resultData?['image_url'];
    if (imageUrl != null && imageUrl.toString().startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
      );
    } else if (imageBytes != null) {
      return Image.memory(
        imageBytes!,
        fit: BoxFit.cover,
      );
    } else {
      return Container(
        color: Colors.grey[200],
        child: const Icon(Icons.image, size: 64, color: Colors.grey),
      );
    }
  }
}
