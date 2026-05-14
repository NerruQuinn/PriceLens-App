import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../data/models/product_model.dart';
import '../../../data/models/price_entry_model.dart';
import '../../../providers/user_provider.dart';

final trendingCategoryProvider = StateProvider<String?>((ref) => null);

final trendingProductsProvider = FutureProvider.autoDispose<List<ProductModel>>((ref) async {
  final category = ref.watch(trendingCategoryProvider);
  
  var query = FirebaseFirestore.instance
      .collection('products')
      .orderBy('submissionCount', descending: true)
      .limit(20);
      
  if (category != null && category.isNotEmpty) {
    query = query.where('category', isEqualTo: category);
  }
  
  final snapshot = await query.get();
  
  return snapshot.docs.map((doc) {
    final data = doc.data();
    data['id'] = doc.id;
    return ProductModel(
      id: doc.id,
      name: data['name'] as String? ?? 'Unknown',
      brand: data['brand'] as String? ?? '',
      category: data['category'] as String? ?? 'Lainnya',
      imageUrl: data['imageUrl'] as String?,
      lastUpdated: data['lastUpdated'] != null
          ? DateTime.tryParse(data['lastUpdated'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }).toList();
});

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final List<Map<String, dynamic>> _categories = [
    {'name': 'Sembako', 'icon': Icons.shopping_cart, 'color': Colors.green},
    {'name': 'Elektronik', 'icon': Icons.computer, 'color': Colors.blue},
    {'name': 'Skincare', 'icon': Icons.sanitizer, 'color': Colors.orange},
    {'name': 'Rumah Tangga', 'icon': Icons.chair, 'color': Colors.purple},
    {'name': 'Fashion', 'icon': Icons.checkroom, 'color': Colors.pink},
    {'name': 'Lainnya', 'icon': Icons.more_horiz, 'color': Colors.grey},
  ];

  Future<void> _onRefresh() async {
    ref.invalidate(trendingProductsProvider);
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return const FilterBottomSheetContent();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final trendingAsync = ref.watch(trendingProductsProvider);
    final selectedCategory = ref.watch(trendingCategoryProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text(
          'PriceLens ID',
          style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {},
          ),
        ],
      ),
      drawer: const Drawer(), // Opsional
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      readOnly: true,
                      onTap: () {
                        // Navigasi ke search screen atau aktifkan inline search
                      },
                      decoration: InputDecoration(
                        hintText: 'Cari harga, produk, atau toko...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _showFilterBottomSheet,
                    icon: const Icon(Icons.tune),
                  ),
                ],
              ),
            ),

            // Kategori Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Kategori', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final isSelected = selectedCategory == cat['name'];
                      return InkWell(
                        onTap: () {
                          if (isSelected) {
                            ref.read(trendingCategoryProvider.notifier).state = null;
                          } else {
                            ref.read(trendingCategoryProvider.notifier).state = cat['name'] as String;
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? colorScheme.primaryContainer : colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(cat['icon'] as IconData, color: cat['color'] as Color, size: 20),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  cat['name'] as String,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Trending Hari Ini Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  const Text('Trending Hari Ini 🔥', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  Icon(Icons.trending_up, color: Colors.green[600], size: 20),
                ],
              ),
            ),
            const SizedBox(height: 12),
            trendingAsync.when(
              data: (products) => _buildTrendingList(products),
              loading: () => _buildLoadingShimmer(),
              error: (err, stack) => _buildErrorState(err.toString()),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendingList(List<ProductModel> products) {
    if (products.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(Icons.search_off, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('Tidak ada produk ditemukan', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return TrendingCard(product: product, rank: index + 1);
      },
    );
  }

  Widget _buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: const SizedBox(height: 100, width: double.infinity),
          );
        },
      ),
    );
  }

  Widget _buildErrorState(String errorMsg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Terjadi kesalahan:\n$errorMsg', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref.invalidate(trendingProductsProvider),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

class TrendingCard extends ConsumerWidget {
  final ProductModel product;
  final int rank;

  const TrendingCard({super.key, required this.product, required this.rank});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String pId = product.id;
    final String pName = product.name;
    final String pCategory = product.category;
    final String? pImage = product.imageUrl;



    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          if (pId.isNotEmpty) {
            context.go('/result/$pId');
          }
        },
        child: SizedBox(
          height: 100,
          child: Row(
            children: [
              // Rank & Image
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (pImage != null)
                      Image.network(pImage, fit: BoxFit.cover)
                    else
                      Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.image, color: Colors.grey, size: 40),
                      ),
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.only(bottomRight: Radius.circular(8)),
                        ),
                        child: Text(
                          '#$rank',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(pCategory, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(pName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const Spacer(),
                      // Lowest Price Loader
                      LowestPriceWidget(productId: pId),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LowestPriceWidget extends ConsumerWidget {
  final String productId;
  const LowestPriceWidget({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestoreService = ref.watch(firestoreServiceProvider);
    
    return FutureBuilder<PriceEntryModel?>(
      future: firestoreService.getLowestPrice(productId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text('Loading...', style: TextStyle(fontSize: 12, color: Colors.grey));
        }
        
        final lowest = snapshot.data;
        if (lowest == null) {
          return const Text('Harga belum tersedia', style: TextStyle(fontSize: 12, color: Colors.grey));
        }

        final price = (lowest as dynamic).price as double? ?? 0.0;
        final store = (lowest as dynamic).storeName?.toString() ?? 'Unknown';

        final formattedPrice = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(price);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(formattedPrice, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 14)),
            Row(
              children: [
                const Icon(Icons.storefront, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(child: Text(store, style: const TextStyle(color: Colors.grey, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ],
        );
      },
    );
  }
}

class FilterBottomSheetContent extends StatefulWidget {
  const FilterBottomSheetContent({super.key});

  @override
  State<FilterBottomSheetContent> createState() => _FilterBottomSheetContentState();
}

class _FilterBottomSheetContentState extends State<FilterBottomSheetContent> {
  RangeValues _priceRange = const RangeValues(0, 10000000);
  String _sortBy = 'Terbaru';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 16.0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filter', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          
          const Text('Range Harga', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          RangeSlider(
            values: _priceRange,
            min: 0,
            max: 10000000,
            divisions: 100,
            labels: RangeLabels(
              NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(_priceRange.start),
              NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(_priceRange.end),
            ),
            onChanged: (values) {
              setState(() {
                _priceRange = values;
              });
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(_priceRange.start)),
              Text(NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(_priceRange.end)),
            ],
          ),
          
          const SizedBox(height: 24),
          const Text('Urutkan', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['Terbaru', 'Termurah', 'Termahal'].map((sortOption) {
              final isSelected = _sortBy == sortOption;
              return ChoiceChip(
                label: Text(sortOption),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _sortBy = sortOption;
                  });
                },
              );
            }).toList(),
          ),
          
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Terapkan Filter'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                setState(() {
                  _priceRange = const RangeValues(0, 10000000);
                  _sortBy = 'Terbaru';
                });
              },
              child: const Text('Reset'),
            ),
          ),
        ],
      ),
    );
  }
}
