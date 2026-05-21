import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../data/models/basket_model.dart';
import '../../../data/services/gemini_service.dart';

import '../../../data/services/storage_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/user_provider.dart';

class BasketEstimatorScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? extra;

  const BasketEstimatorScreen({super.key, this.extra});

  @override
  ConsumerState<BasketEstimatorScreen> createState() => _BasketEstimatorScreenState();
}

class _BasketEstimatorScreenState extends ConsumerState<BasketEstimatorScreen> {
  BasketModel? _basket;
  bool _isAnalyzing = false;
  Uint8List? _basketImageBytes;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.extra != null && widget.extra!.containsKey('imageBytes')) {
      _basketImageBytes = widget.extra!['imageBytes'] as Uint8List?;
      if (_basketImageBytes != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _analyzeBasket(_basketImageBytes!);
        });
      }
    }
  }

  Future<void> _analyzeBasket(Uint8List imageBytes) async {
    if (!mounted) return;
    debugPrint('[BasketEstimator] _analyzeBasket called with ${imageBytes.length} bytes');
    setState(() {
      _isAnalyzing = true;
      _basketImageBytes = imageBytes;
      _errorMessage = null;
    });

    try {
      final geminiService = GeminiService();
      final firestoreService = ref.read(firestoreServiceProvider);
      final storageService = StorageService();
      final user = ref.read(currentUserModelProvider).value;

      debugPrint('[BasketEstimator] Calling analyzeBasket...');
      final result = await geminiService.analyzeBasket(imageBytes);

      if (result != null) {
        // Parse response ke BasketModel
        final itemsData = result['items'] ?? [];
        final basketMap = {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'userId': user?.id ?? 'guest',
          'storeName': result['store_name'] ?? 'Unknown Store',
          'items': itemsData,
          'totalEstimate': result['total_estimate'] ?? result['total'] ?? 0.0,
          'timestamp': DateTime.now().toIso8601String(),
          'savingsPotential': result['savings_potential'] ?? 0.0,
          'savingsTip': result['savings_tip'] ?? '',
        };

        BasketModel basket;
        try {
          // Assume BasketModel has a fromMap that can parse the items
          basket = BasketModel.fromMap(basketMap);
        } catch (e) {
          debugPrint('BasketModel.fromMap error: $e');
          rethrow;
        }

        // Upload photo ke storage
        String? photoUrl;
        if (user != null) {
          photoUrl = await storageService.uploadBasketPhoto(imageBytes, user.id);
          basket = basket.copyWith(photoUrl: photoUrl);
        }

        // Simpan basket ke Firestore
        if (user != null) {
          try {
            await (firestoreService as dynamic).saveBasket(basket);
          } catch (e) {
            debugPrint('Failed to save basket to firestore: $e');
          }
        }

        if (mounted) {
          setState(() {
            _basket = basket;
            _isAnalyzing = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = "Gagal menganalisis keranjang";
            _isAnalyzing = false;
          });
        }
      }
    } catch (e, stack) {
      debugPrint('[BasketEstimator] Error: $e');
      debugPrint('[BasketEstimator] Stack: $stack');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isAnalyzing = false;
        });
      }
    }
  }

  Future<void> _captureBasket() async {
    debugPrint('[BasketEstimator] Camera button pressed');
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(source: ImageSource.camera);
      debugPrint('[BasketEstimator] Camera image: ${photo?.path}');
      if (photo != null) {
        final bytes = await photo.readAsBytes();
        _analyzeBasket(bytes);
      }
    } catch (e) {
      debugPrint('[BasketEstimator] Camera capture error: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    debugPrint('[BasketEstimator] Gallery button pressed');
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(source: ImageSource.gallery);
      debugPrint('[BasketEstimator] Image picked: ${photo?.path}');
      if (photo != null) {
        final bytes = await photo.readAsBytes();
        _analyzeBasket(bytes);
      }
    } catch (e) {
      debugPrint('[BasketEstimator] Gallery pick error: $e');
    }
  }

  Future<void> _saveBasket() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Estimasi berhasil disimpan')),
    );
    context.pop();
  }

  String formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(amount).trim();
  }

  String _normalizeConfidence(String? confidence) {
    if (confidence == null || confidence.isEmpty) return 'medium';
    final lower = confidence.toLowerCase();
    if (lower == 'high' || lower == 'medium' || lower == 'low') {
      return lower;
    }
    
    final regex = RegExp(r'\d+');
    final match = regex.firstMatch(confidence);
    if (match != null) {
      final value = int.tryParse(match.group(0) ?? '') ?? 0;
      if (value >= 80) return 'high';
      if (value >= 50) return 'medium';
      return 'low';
    }
    return 'medium';
  }

  Color _getConfidenceColor(String? confidence) {
    switch (confidence?.toLowerCase()) {
      case 'high':
        return Colors.green;
      case 'medium':
        return Colors.amber;
      case 'low':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_isAnalyzing && _basketImageBytes != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Smart Basket')),
        body: Stack(
          children: [
            Opacity(
              opacity: 0.3,
              child: Image.memory(
                _basketImageBytes!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(strokeWidth: 6),
                  ),
                  const SizedBox(height: 24),
                  Text('Menganalisis keranjang...', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('AI sedang mengenali semua produk', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 48.0),
                    child: LinearProgressIndicator(),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_basket == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Smart Basket'),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {},
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shopping_basket_outlined, size: 120, color: Colors.grey),
                const SizedBox(height: 24),
                Text('Foto Keranjang Belanjamu', style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  'AI akan mengenali semua produk\ndan estimasi total harga',
                  style: textTheme.bodyLarge?.copyWith(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                FilledButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Ambil Foto Sekarang'),
                  onPressed: _captureBasket,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(200, 52),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Pilih dari Galeri'),
                  onPressed: _pickFromGallery,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(200, 52),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 24),
                  Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
        ),
      );
    }

    // Result State
    final itemsList = _basket!.items;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Basket'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _basket = null;
                _basketImageBytes = null;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.save_outlined),
            onPressed: _saveBasket,
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // a) FOTO & TOTAL
          SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_basketImageBytes != null)
                    Image.memory(_basketImageBytes!, fit: BoxFit.cover, width: double.infinity)
                  else if (_basket!.photoUrl != null)
                    Image.network(_basket!.photoUrl!, fit: BoxFit.cover, width: double.infinity),
                  
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${itemsList.length} item terdeteksi',
                          style: const TextStyle(color: Colors.white),
                        ),
                        const Text(
                          'Estimasi Total',
                          style: TextStyle(color: Colors.white70),
                        ),
                        Text(
                          'Rp ${formatCurrency(_basket!.totalEstimate)}',
                          style: textTheme.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // b) POTENSI HEMAT
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                color: Colors.green.shade50,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.savings, color: Colors.green, size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Potensi Hemat', style: textTheme.titleMedium?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
                            Text(
                              _basket!.savingsTip.isNotEmpty ? _basket!.savingsTip : 'Beli di toko rekomendasi untuk harga terbaik',
                              style: textTheme.bodySmall?.copyWith(color: Colors.green.shade800),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Rp ${formatCurrency(_basket!.savingsPotential)}',
                        style: textTheme.titleMedium?.copyWith(color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // c) ITEMS
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
              child: Text('Detail Item', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = itemsList[index];
                final itemName = item.name;
                final itemQuantity = item.quantity.toString();
                final itemCheapestStore = item.cheapestStore;
                final itemConfidence = _normalizeConfidence(item.confidence);
                final itemSubtotal = item.subtotal;
                final itemUnitPrice = item.unitPriceEstimate;

                return ListTile(
                  leading: CircleAvatar(child: Text(itemQuantity)),
                  title: Text(itemName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Row(
                    children: [
                      Expanded(
                        child: Text(
                          itemCheapestStore,
                          style: textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getConfidenceColor(itemConfidence),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          itemConfidence,
                          style: textTheme.bodySmall?.copyWith(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Rp ${formatCurrency(itemSubtotal)}',
                        style: textTheme.titleSmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '@ Rp ${formatCurrency(itemUnitPrice)}',
                        style: textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              },
              childCount: itemsList.length,
            ),
          ),

          // d) BOTTOM PADDING
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        elevation: 8,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: _saveBasket,
                child: const Text('Simpan Estimasi'),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _basket = null;
                  _basketImageBytes = null;
                });
              },
              child: const Text('Scan Ulang'),
            ),
          ],
        ),
      ),
    );
  }
}
