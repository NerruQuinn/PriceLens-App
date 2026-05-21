import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../data/models/product_model.dart';
import '../../../data/models/price_entry_model.dart';
import '../../../providers/user_provider.dart';
import '../../../data/services/user_service.dart';

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
    {'name': 'Sembako', 'icon': Icons.shopping_basket, 'type': 'sembako'},
    {'name': 'Elektronik', 'icon': Icons.computer, 'type': 'elektronik'},
    {'name': 'Skincare', 'icon': Icons.face_retouching_natural, 'type': 'skincare'},
    {'name': 'Rumah Tangga', 'icon': Icons.chair, 'type': 'rumah_tangga'},
    {'name': 'Fashion', 'icon': Icons.checkroom, 'type': 'fashion'},
    {'name': 'Lainnya', 'icon': Icons.more_horiz, 'type': 'lainnya'},
  ];

  Color _getCategoryColor(String type, ColorScheme colorScheme) {
    switch (type) {
      case 'sembako': return colorScheme.primaryContainer;
      case 'elektronik': return colorScheme.secondaryContainer;
      case 'skincare': return colorScheme.tertiaryContainer;
      case 'rumah_tangga': return colorScheme.primary.withValues(alpha: 0.2);
      case 'fashion': return colorScheme.errorContainer;
      case 'lainnya': return colorScheme.surfaceContainerHighest;
      default: return colorScheme.surfaceContainerHighest;
    }
  }

  Color _getCategoryIconColor(String type, ColorScheme colorScheme) {
    switch (type) {
      case 'sembako': return colorScheme.onPrimaryContainer;
      case 'elektronik': return colorScheme.onSecondaryContainer;
      case 'skincare': return colorScheme.onTertiaryContainer;
      case 'rumah_tangga': return colorScheme.primary;
      case 'fashion': return colorScheme.onErrorContainer;
      case 'lainnya': return colorScheme.onSurfaceVariant;
      default: return colorScheme.onSurfaceVariant;
    }
  }

  List<Map<String, dynamic>> _communityItems = [];
  bool _communityLoading = true;
  final _userService = UserService();

  @override
  void initState() {
    super.initState();
    _loadCommunity();
  }

  Future<void> _loadCommunity() async {
    setState(() => _communityLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('community_submissions')
          .limit(10)
          .get();

      final docs = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      docs.sort((a, b) {
        final tA = a['timestamp'] as Timestamp?;
        final tB = b['timestamp'] as Timestamp?;
        if (tA == null || tB == null) return 0;
        return tB.compareTo(tA);
      });

      final List<Map<String, dynamic>> enriched = [];
      for (final doc in docs) {
        final userId = doc['userId'] as String? ?? '';
        final name = userId.isNotEmpty
            ? await _userService.getDisplayName(userId)
            : 'Pengguna PriceLens';
        final initial = name.length >= 2
            ? name.substring(0, 2).toUpperCase()
            : name.isNotEmpty ? name[0].toUpperCase() : 'PL';
        final ts = doc['timestamp'] as Timestamp?;
        String timeStr = 'Baru saja';
        if (ts != null) {
          final diff = DateTime.now().difference(ts.toDate());
          if (diff.inMinutes < 60) {
            timeStr = '${diff.inMinutes} menit lalu';
          } else if (diff.inHours < 24) {
            timeStr = '${diff.inHours} jam lalu';
          } else {
            timeStr = '${diff.inDays} hari lalu';
          }
        }
        enriched.add({
          ...doc,
          'displayName': name,
          'initial': initial,
          'timeStr': timeStr,
          'upvoted': false,
        });
      }

      if (!mounted) return;
      setState(() {
        _communityItems = enriched;
        _communityLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _communityLoading = false);
    }
  }

  Future<void> _upvote(int index) async {
    final item = _communityItems[index];
    final docId = item['id'] as String;
    await FirebaseFirestore.instance
        .collection('community_submissions')
        .doc(docId)
        .update({'upvotes': FieldValue.increment(1)});
    setState(() {
      _communityItems[index] = {
        ...item,
        'upvotes': ((item['upvotes'] as num?)?.toInt() ?? 0) + 1,
        'upvoted': true,
      };
    });
  }

  Future<void> _onRefresh() async {
    ref.invalidate(trendingProductsProvider);
    await _loadCommunity();
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
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          'Eksplor',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
        ],
      ),
      drawer: const Drawer(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              // 1. Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  readOnly: true,
                  onTap: () {
                    // Navigasi ke search screen
                  },
                  decoration: InputDecoration(
                    hintText: 'Cari harga, produk, atau toko...',
                    hintStyle: textTheme.bodyMedium?.copyWith(color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.tune, color: Colors.grey),
                      onPressed: _showFilterBottomSheet,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                ),
              ),
            ),

            // 2. Kategori Grid
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kategori Pilihan', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 2.5,
                    ),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final isSelected = selectedCategory == cat['name'];
                      final bgColor = _getCategoryColor(cat['type'], colorScheme);
                      final iconColor = _getCategoryIconColor(cat['type'], colorScheme);

                      return Material(
                        color: isSelected ? colorScheme.surfaceContainerHigh : colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onHover: (hovering) {
                            // Hover effect otomatis dihandle InkWell Material
                          },
                          onTap: () {
                            if (isSelected) {
                              ref.read(trendingCategoryProvider.notifier).state = null;
                            } else {
                              ref.read(trendingCategoryProvider.notifier).state = cat['name'] as String;
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: bgColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(cat['icon'], color: iconColor, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    cat['name'] as String,
                                    style: textTheme.labelLarge?.copyWith(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // 3. Trending Hari Ini
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Text('Trending Hari Ini', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton(
                    onPressed: () {},
                    child: const Text('Lihat Semua'),
                  ),
                ],
              ),
            ),
            trendingAsync.when(
              data: (products) => _buildTrendingListHorizontal(products, textTheme, colorScheme),
              loading: () => _buildLoadingShimmerHorizontal(),
              error: (err, stack) => _buildErrorState(err.toString()),
            ),

            // 4. Diskon Terbesar
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
              child: Row(
                children: [
                  Text('Diskon Terbesar', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            _buildDiscountList(textTheme, colorScheme),

            // 5. Aktivitas Komunitas
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 32.0, 16.0, 16.0),
              child: Text('Aktivitas Komunitas', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            ),
            _buildCommunityFeed(textTheme, colorScheme),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildTrendingListHorizontal(List<ProductModel> products, TextTheme textTheme, ColorScheme colorScheme) {
    if (products.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('Tidak ada produk trending', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return SizedBox(
      height: 250,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return TrendingCardHorizontal(product: product, rank: index + 1);
        },
      ),
    );
  }

  Widget _buildLoadingShimmerHorizontal() {
    return SizedBox(
      height: 250,
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          itemCount: 5,
          itemBuilder: (context, index) {
            return Container(
              width: 150,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDiscountList(TextTheme textTheme, ColorScheme colorScheme) {
    // Mock Data for Diskon Terbesar
    final mockDiscounts = [
      {'name': 'Minyak Goreng 2L', 'oldPrice': 40000.0, 'newPrice': 28000.0, 'discount': '30%'},
      {'name': 'Sabun Mandi Cair 450ml', 'oldPrice': 25000.0, 'newPrice': 15000.0, 'discount': '40%'},
      {'name': 'Beras Premium 5kg', 'oldPrice': 75000.0, 'newPrice': 60000.0, 'discount': '20%'},
    ];

    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: mockDiscounts.length,
        itemBuilder: (context, index) {
          final item = mockDiscounts[index];
          return Container(
            width: 280,
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 80, height: 80,
                    color: colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.image, color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('Diskon ${item['discount']}', style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 4),
                      Text(item['name'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Text(
                              NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(item['oldPrice']),
                              style: textTheme.labelSmall?.copyWith(decoration: TextDecoration.lineThrough, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(item['newPrice']),
                              style: textTheme.titleSmall?.copyWith(color: Colors.red, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCommunityFeed(TextTheme textTheme, ColorScheme colorScheme) {
    if (_communityLoading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_communityItems.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Center(
          child: Text('Belum ada aktivitas komunitas', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _communityItems.length,
      itemBuilder: (context, index) {
        final feed = _communityItems[index];
        final isUpvoted = feed['upvoted'] as bool? ?? false;
        final upvotes = (feed['upvotes'] as num?)?.toInt() ?? 0;
        final name = feed['displayName'] as String? ?? 'Pengguna';
        final initial = feed['initial'] as String? ?? 'PL';
        final product = feed['product_name'] as String? ?? 'Produk';
        final store = feed['store_name'] as String? ?? 'Toko';
        final timeStr = feed['timeStr'] as String? ?? '';

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: colorScheme.secondaryContainer,
                child: Text(initial, style: TextStyle(color: colorScheme.onSecondaryContainer, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
                        children: [
                          TextSpan(text: '$name ', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const TextSpan(text: 'menemukan harga untuk '),
                          TextSpan(text: '$product ', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const TextSpan(text: 'di '),
                          TextSpan(text: store, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(timeStr, style: textTheme.bodySmall?.copyWith(color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: isUpvoted ? null : () => _upvote(index),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isUpvoted ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.arrow_upward, size: 16, color: isUpvoted ? colorScheme.primary : colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text('$upvotes', style: TextStyle(color: isUpvoted ? colorScheme.primary : colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
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

class TrendingCardHorizontal extends ConsumerWidget {
  final ProductModel product;
  final int rank;

  const TrendingCardHorizontal({super.key, required this.product, required this.rank});

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'sembako': return Icons.shopping_basket;
      case 'elektronik': return Icons.computer;
      case 'skincare': return Icons.face_retouching_natural;
      case 'rumah tangga': return Icons.chair;
      case 'fashion': return Icons.checkroom;
      default: return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String pId = product.id;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (pId.isNotEmpty) {
            context.go('/result/$pId');
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      color: colorScheme.surfaceContainerHighest,
                      child: Icon(
                        _getCategoryIcon(product.category),
                        size: 48,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: colorScheme.primary,
                    child: Text('#$rank', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Akurat', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(product.category, style: textTheme.labelSmall?.copyWith(fontSize: 9)),
                    ),
                    const SizedBox(height: 4),
                    Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 12)),
                    const Spacer(),
                    LowestPriceWidgetHorizontal(productId: pId),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LowestPriceWidgetHorizontal extends ConsumerWidget {
  final String productId;
  const LowestPriceWidgetHorizontal({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestoreService = ref.watch(firestoreServiceProvider);
    final colorScheme = Theme.of(context).colorScheme;
    
    return FutureBuilder<PriceEntryModel?>(
      future: firestoreService.getLowestPrice(productId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text('...', style: TextStyle(fontSize: 12, color: Colors.grey));
        }
        
        final lowest = snapshot.data;
        if (lowest == null) {
          return const Text('Harga blm ada', style: TextStyle(fontSize: 10, color: Colors.grey));
        }

        final price = (lowest as dynamic).price as double? ?? 0.0;
        final store = (lowest as dynamic).storeName?.toString() ?? 'Toko';

        final formattedPrice = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(price);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(formattedPrice, style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
            Row(
              children: [
                const Icon(Icons.storefront, size: 10, color: Colors.grey),
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
              Flexible(child: Text(NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(_priceRange.start), overflow: TextOverflow.ellipsis)),
              Flexible(child: Text(NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(_priceRange.end), overflow: TextOverflow.ellipsis)),
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
