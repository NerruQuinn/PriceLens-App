import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../providers/auth_provider.dart';
import '../../../data/services/gemini_service.dart';
import '../../../data/services/user_service.dart';
import '../../../data/services/product_image_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── Currency formatter ───────────────────────────────────────────────────────
final _rupiahFmt = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

String _rp(double v) => _rupiahFmt.format(v);

Future<void> _launchProductSearch(String productName, String storeName) async {
  final query = Uri.encodeComponent('$productName $storeName harga Indonesia');
  final uri = Uri.parse('https://www.google.com/search?q=$query');
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

String timeAgo(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
  if (diff.inHours < 24) return '${diff.inHours} jam lalu';
  return '${diff.inDays} hari lalu';
}

const _categories = [
  {'label': 'Makanan & Minuman', 'icon': Icons.restaurant},
  {'label': 'Elektronik', 'icon': Icons.devices},
  {'label': 'Skincare', 'icon': Icons.face_retouching_natural},
  {'label': 'Kebutuhan Rumah', 'icon': Icons.home},
];

// ─── Screen ───────────────────────────────────────────────────────────────────
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final Map<int, bool> _upvoted = {};
  bool _isExpanded = false;
  Timer? _collapseTimer;
  final _userService = UserService();

  bool _isLoadingData = true;
  bool _hasError = false;
  bool _isSearching = false;
  List<Map<String, dynamic>> _promos = [];
  List<Map<String, dynamic>> _popular = [];
  List<Map<String, dynamic>> _community = [];
  Map<String, String> _promoImages = {};
  Map<String, String> _trendingImages = {};

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    setState(() {
      _isLoadingData = true;
      _hasError = false;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final docRef = firestore.collection('promo_cache').doc('daily_promos');

      Map<String, dynamic>? data;

      // Check Firestore cache first
      final docSnap = await docRef.get();
      if (docSnap.exists) {
        final cached = docSnap.data()!;
        final cachedAt = cached['cached_at'] as Timestamp?;
        if (cachedAt != null &&
            DateTime.now().difference(cachedAt.toDate()).inHours < 6) {
          data = cached['data'] as Map<String, dynamic>?;
        }
      }

      // Cache miss or expired — fetch from Gemini
      if (data == null) {
        data = await GeminiService().getPromoData();
        if (data != null) {
          await docRef.set({
            'data': data,
            'cached_at': FieldValue.serverTimestamp(),
          });
        }
      }

      // Fetch community submissions
      List<Map<String, dynamic>> communityData = [];
      try {
        final querySnapshot = await firestore
            .collection('community_submissions')
            .where('status', isEqualTo: 'pending')
            .orderBy('timestamp', descending: true)
            .limit(5)
            .get();
        communityData = querySnapshot.docs.map((doc) => doc.data()).toList();
      } catch (e) {
        // Fallback if index is missing
        try {
          final fallbackSnapshot = await firestore
              .collection('community_submissions')
              .limit(10)
              .get();
          final docs = fallbackSnapshot.docs.map((doc) => doc.data()).toList();
          docs.sort((a, b) {
            final tA = a['timestamp'] as Timestamp?;
            final tB = b['timestamp'] as Timestamp?;
            if (tA == null || tB == null) return 0;
            return tB.compareTo(tA);
          });
          communityData = docs;
        } catch (_) {}
      }

      // Enrich community data with real display names
      final List<Map<String, dynamic>> enrichedCommunity = [];
      for (final x in communityData) {
        final userId = x['userId'] as String? ?? '';
        final name = userId.isNotEmpty
            ? await _userService.getDisplayName(userId)
            : 'Pengguna PriceLens';
        final initial = name.length >= 2
            ? name.substring(0, 2).toUpperCase()
            : name.isNotEmpty ? name[0].toUpperCase() : 'PL';
        final ts = x['timestamp'] as Timestamp?;
        final timeStr = ts != null ? timeAgo(ts.toDate()) : 'Baru saja';
        enrichedCommunity.add({
          'user': name,
          'initial': initial,
          'avatarColor': 0xFF1976D2,
          'time': timeStr,
          'store': x['store_name'] ?? 'Toko',
          'product': x['product_name'] ?? 'Produk',
          'price': (x['price'] as num?)?.toDouble() ?? 0.0,
          'upvotes': (x['upvotes'] as num?)?.toInt() ?? 0,
        });
      }

      if (!mounted) return;
      setState(() {
        _isLoadingData = false;
        _community = enrichedCommunity;
        if (data != null) {
          if (data['promos'] != null) {
            _promos = List<Map<String, dynamic>>.from(
              (data['promos'] as List).map((x) => {
                'name': x['name'] ?? '',
                'store': x['store'] ?? '',
                'originalPrice': (x['original_price'] as num?)?.toDouble() ?? 0.0,
                'discountPrice': (x['discount_price'] as num?)?.toDouble() ?? 0.0,
                'discount': x['discount_percent'] != null ? '-${x['discount_percent']}%' : '',
                'color': 0xFFFFF9C4,
              }),
            );
          }
          if (data['trending'] != null) {
            _popular = List<Map<String, dynamic>>.from(
              (data['trending'] as List).map((x) => {
                'name': x['name'] ?? '',
                'price': (x['price'] as num?)?.toDouble() ?? 0.0,
                'isTrending': true,
                'color': 0xFFF1F8E9,
              }),
            );
          }
        } else {
          _hasError = true;
        }
      });
      _fetchImagesForProducts();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingData = false;
        _hasError = true;
      });
    }
  }

  Future<void> _fetchImagesForProducts() async {
    for (var promo in _promos) {
      final name = promo['name']?.toString() ?? '';
      if (name.isNotEmpty && !_promoImages.containsKey(name)) {
        final url = await ProductImageService.getProductImage(name);
        if (url != null && mounted) {
          setState(() => _promoImages[name] = url);
        }
      }
    }
    for (var product in _popular) {
      final name = product['name']?.toString() ?? '';
      if (name.isNotEmpty && !_trendingImages.containsKey(name)) {
        final url = await ProductImageService.getProductImage(name);
        if (url != null && mounted) {
          setState(() => _trendingImages[name] = url);
        }
      }
    }
  }

  Future<void> _searchProduct(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isSearching = true);
    try {
      final result = await GeminiService().analyzeProductFromBarcode(query.trim());
      if (!mounted) return;
      setState(() => _isSearching = false);
      if (result != null) {
        context.push('/result', extra: {'data': result, 'type': 'search', 'query': query.trim()});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produk tidak ditemukan, coba kata kunci lain')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSearching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserModelProvider);
    final displayName = userAsync.value?.displayName ?? 'Budi';
    final email = userAsync.value?.email ?? '';
    final points = userAsync.value?.points ?? 1250;

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: _buildAppBar(context, cs, tt),
      drawer: _buildDrawer(context, displayName, email, points),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _buildHeaderRow(tt, displayName, points),
                  const SizedBox(height: 20),
                  _buildSearchBar(context, cs),
                  const SizedBox(height: 24),
                  _buildCategorySection(cs, tt),
                  const SizedBox(height: 24),
                  _buildPromoSection(context, cs, tt),
                  const SizedBox(height: 24),
                  _buildPopularSection(cs, tt),
                  const SizedBox(height: 16),
                  _buildSubmitBanner(context),
                  const SizedBox(height: 16),
                  _buildCommunitySection(context, cs, tt),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          if (_isSearching)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 16),
                        Text('Mencari produk...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1976D2),
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        onPressed: () {
          if (!_isExpanded) {
            setState(() => _isExpanded = true);
            _collapseTimer?.cancel();
            _collapseTimer = Timer(const Duration(seconds: 3), () {
              if (mounted) setState(() => _isExpanded = false);
            });
          } else {
            context.go('/scan');
          }
        },
        isExtended: _isExpanded,
        icon: const Icon(Icons.camera_alt_outlined, color: Colors.white),
        label: const Text(
          'Scan Sekarang',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────
  AppBar _buildAppBar(BuildContext context, ColorScheme cs, TextTheme tt) {
    return AppBar(
      backgroundColor: const Color(0xFFFAFAFA),
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu, color: Colors.black54),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      centerTitle: true,
      title: Text(
        'PriceLens ID',
        style: tt.titleMedium?.copyWith(
          color: const Color(0xFF1976D2), // Primary Blue
          fontWeight: FontWeight.w800,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.black54),
          onPressed: _isLoadingData ? null : _loadHomeData,
        ),
        Badge(
          smallSize: 10,
          backgroundColor: Colors.redAccent,
          child: IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black54),
            onPressed: () {},
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ── Header Row ────────────────────────────────────────────────────────────
  Widget _buildHeaderRow(TextTheme tt, String name, int points) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Halo, $name',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Siap berbelanja cerdas hari ini?',
              style: tt.bodySmall?.copyWith(color: Colors.black54),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFE082).withValues(alpha: 0.5), // Light amber
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.stars, color: Color(0xFFF57F17), size: 18),
              const SizedBox(width: 6),
              Text(
                NumberFormat('#,###').format(points).replaceAll(',', '.'),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Color(0xFF5D4037),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Search bar ────────────────────────────────────────────────────────────
  Widget _buildSearchBar(BuildContext context, ColorScheme cs) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.only(left: 16, right: 8),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.black54, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Cari produk atau scan...',
                hintStyle: TextStyle(color: Colors.black54, fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: _searchProduct,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF1976D2), size: 20),
            onPressed: () => context.go('/scan'),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  // ── Category Section ──────────────────────────────────────────────────────
  Widget _buildCategorySection(ColorScheme cs, TextTheme tt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Jelajahi Kategori',
          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: _categories.map((cat) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(cat['icon'] as IconData, size: 16, color: Colors.black87),
                      const SizedBox(width: 8),
                      Text(
                        cat['label'] as String,
                        style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w500, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── Promo Section ─────────────────────────────────────────────────────────
  Widget _buildPromoSection(BuildContext context, ColorScheme cs, TextTheme tt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Promo Sekarang',
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: Colors.black87),
            ),
            TextButton(
              onPressed: () => context.go('/explore'),
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('Lihat Semua', style: TextStyle(fontSize: 12, color: const Color(0xFF1976D2))),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _isLoadingData
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              )
            : _hasError || _promos.isEmpty
                ? GestureDetector(
                    onTap: _hasError ? _loadHomeData : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      alignment: Alignment.center,
                      child: Text(
                        _hasError
                            ? 'Tap refresh untuk memuat promo'
                            : 'Tidak ada promo hari ini',
                        style: TextStyle(color: Colors.black45, fontSize: 13),
                      ),
                    ),
                  )
                : SizedBox(
                    height: 240,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      itemCount: _promos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, i) {
                        final p = _promos[i];
                        return _PromoCard(
                          promo: p,
                          cs: cs,
                          tt: tt,
                          imageUrl: _promoImages[p['name']?.toString() ?? ''],
                        );
                      },
                    ),
                  ),
      ],
    );
  }

  // ── Popular Section ───────────────────────────────────────────────────────
  Widget _buildPopularSection(ColorScheme cs, TextTheme tt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rak Populer',
          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        const SizedBox(height: 12),
        _isLoadingData
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              )
            : _hasError || _popular.isEmpty
                ? GestureDetector(
                    onTap: _hasError ? _loadHomeData : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      alignment: Alignment.center,
                      child: Text(
                        _hasError
                            ? 'Tap refresh untuk memuat promo'
                            : 'Belum ada data populer',
                        style: TextStyle(color: Colors.black45, fontSize: 13),
                      ),
                    ),
                  )
                : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.82,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _popular.length,
                    itemBuilder: (context, i) {
                      final p = _popular[i];
                      return _PopularCard(
                        product: p,
                        cs: cs,
                        tt: tt,
                        imageUrl: _trendingImages[p['name']?.toString() ?? ''],
                      );
                    },
                  ),
      ],
    );
  }

  // ── Community Section ─────────────────────────────────────────────────────
  Widget _buildCommunitySection(BuildContext context, ColorScheme cs, TextTheme tt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Baru dari Komunitas',
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: Colors.black87),
            ),
            TextButton(
              onPressed: () => context.push('/community'),
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Lihat Semua →', style: TextStyle(fontSize: 12, color: Color(0xFF1976D2))),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _community.isEmpty && !_isLoadingData
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Belum ada submission dari komunitas.',
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _community.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final c = _community[i];
                  final upvoted = _upvoted[i] ?? false;
                  final upvotes = (c['upvotes'] as int) + (upvoted ? 1 : 0);
                  
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Color(c['avatarColor'] as int),
                          child: Text(
                            c['initial'] as String,
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${c['user']} submit harga ${c['product']} di ${c['store']}',
                                style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: Colors.black87),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${c['time']} • Harga: ${_rp(c['price'] as double)}',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setState(() => _upvoted[i] = !upvoted),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                upvoted ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                                size: 20,
                                color: upvoted ? const Color(0xFF1976D2) : Colors.black54,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$upvotes',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: upvoted ? const Color(0xFF1976D2) : Colors.black54,
                                  fontWeight: upvoted ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ],
    );
  }

  // ── Drawer ────────────────────────────────────────────────────────────────
  Widget _buildDrawer(BuildContext context, String name, String email, int points) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF1976D2)),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1976D2),
                ),
              ),
            ),
            accountName: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            accountEmail: Text(email, style: const TextStyle(fontSize: 12)),
            otherAccountsPictures: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE082),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stars, size: 14, color: Color(0xFFF57F17)),
                    const SizedBox(width: 4),
                    Text(
                      NumberFormat('#,###').format(points).replaceAll(',', '.'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5D4037),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _drawerItem(
                  icon: Icons.person_outline,
                  label: 'Profil Saya',
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/profile');
                  },
                ),
                _drawerItem(
                  icon: Icons.history,
                  label: 'Riwayat Pencarian',
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/history');
                  },
                ),
                _drawerItem(
                  icon: Icons.add_circle_outline,
                  label: 'Submit Harga',
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/submit');
                  },
                ),
                _drawerItem(
                  icon: Icons.palette_outlined,
                  label: 'Toko Skin',
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/shop');
                  },
                ),
                const Divider(),
                _drawerItem(
                  icon: Icons.info_outline,
                  label: 'Tentang Aplikasi',
                  onTap: () {
                    Navigator.pop(context);
                    showAboutDialog(
                      context: context,
                      applicationName: 'PriceLens ID',
                      applicationVersion: '1.0.0',
                      applicationLegalese: '© 2025 PriceLens ID',
                    );
                  },
                ),
                _drawerItem(
                  icon: Icons.logout,
                  label: 'Keluar',
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(context);
                    ref.read(authServiceProvider).signOut();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.black54, size: 22),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: color ?? Colors.black87,
        ),
      ),
      onTap: onTap,
      dense: true,
      horizontalTitleGap: 8,
    );
  }

  // ── Submit Banner ─────────────────────────────────────────────────────────
  Widget _buildSubmitBanner(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/submit'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_circle_outline, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Temukan harga berbeda?',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Submit & dapat poin!',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Submit',
                style: TextStyle(
                  color: Color(0xFF1976D2),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

// ─── Promo Card ───────────────────────────────────────────────────────────────
class _PromoCard extends StatelessWidget {
  const _PromoCard({required this.promo, required this.cs, required this.tt, this.imageUrl});

  final Map<String, dynamic> promo;
  final ColorScheme cs;
  final TextTheme tt;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final name = promo['name']?.toString() ?? '';
    final store = promo['store']?.toString() ?? '';
    final discount = promo['discount']?.toString() ?? '';
    final discountPrice = (promo['discountPrice'] as num?)?.toDouble() ?? 0.0;
    final originalPrice = (promo['originalPrice'] as num?)?.toDouble() ?? 0.0;
    final color = Color((promo['color'] as num?)?.toInt() ?? 0xFFFFF9C4);
    return GestureDetector(
      onTap: () {
        debugPrint('PROMO TAPPED: $name');
        _launchProductSearch(name, store);
      },
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                    ),
                    child: imageUrl != null
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                            child: CachedNetworkImage(
                              imageUrl: imageUrl!,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => const Center(
                                child: Icon(Icons.local_offer, size: 48, color: Colors.black26),
                              ),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.local_offer, size: 48, color: Colors.black26),
                          ),
                  ),
                  if (discount.isNotEmpty)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD32F2F),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          discount,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store,
                      style: const TextStyle(fontSize: 10, color: Colors.black54),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: Colors.black87, height: 1.2),
                    ),
                    const Spacer(),
                    Text(
                      _rp(discountPrice),
                      style: tt.bodyMedium?.copyWith(
                        color: const Color(0xFF1976D2),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _rp(originalPrice),
                      style: const TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: Colors.black38,
                        fontSize: 10,
                      ),
                    ),
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

// ─── Popular Card ─────────────────────────────────────────────────────────────
class _PopularCard extends StatelessWidget {
  const _PopularCard({required this.product, required this.cs, required this.tt, this.imageUrl});

  final Map<String, dynamic> product;
  final ColorScheme cs;
  final TextTheme tt;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final name = product['name']?.toString() ?? '';
    final store = product['store']?.toString() ?? '';
    final price = (product['price'] as num?)?.toDouble() ?? 0.0;
    final color = Color((product['color'] as num?)?.toInt() ?? 0xFFF1F8E9);
    final isTrending = product['isTrending'] as bool? ?? false;
    return GestureDetector(
      onTap: () {
        debugPrint('RAK POPULER TAPPED: $name');
        _launchProductSearch(name, store);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                    ),
                    child: imageUrl != null
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                            child: CachedNetworkImage(
                              imageUrl: imageUrl!,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => const Center(
                                child: Icon(Icons.shopping_bag, size: 48, color: Colors.black26),
                              ),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.shopping_bag, size: 48, color: Colors.black26),
                          ),
                  ),
                  if (isTrending)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFF8D6E63),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.trending_up, color: Colors.white, size: 12),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: Colors.black87, height: 1.2),
                    ),
                    Text(
                      _rp(price),
                      style: tt.bodyMedium?.copyWith(
                        color: const Color(0xFF1976D2),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
