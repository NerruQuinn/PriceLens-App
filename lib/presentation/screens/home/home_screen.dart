import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../providers/auth_provider.dart';

// ─── Currency formatter ───────────────────────────────────────────────────────
final _rupiahFmt = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

String _rp(double v) => _rupiahFmt.format(v);

// ─── Dummy Data ───────────────────────────────────────────────────────────────
const _promos = [
  {
    'name': 'Minyak Goreng Sunco 2L',
    'store': 'Supermarket ABC',
    'originalPrice': 54000.0,
    'discountPrice': 32500.0,
    'discount': '-40%',
    'emoji': '🛢️',
    'color': 0xFFFFF9C4,
  },
  {
    'name': 'Beras Pandan Wangi 5Kg',
    'store': 'Toko Makmur',
    'originalPrice': 85000.0,
    'discountPrice': 65000.0,
    'discount': '-25%',
    'emoji': '🌾',
    'color': 0xFFE8F5E9,
  },
];

const _popular = [
  {
    'name': 'Kopi Instan Gold 100g',
    'price': 45000.0,
    'isTrending': true,
    'emoji': '☕',
    'color': 0xFFD7CCC8,
  },
  {
    'name': 'Sabun Cuci Piring Lemon 750ml',
    'price': 15500.0,
    'isTrending': true,
    'emoji': '🧴',
    'color': 0xFFF1F8E9,
  },
  {
    'name': 'Tisu Toilet Premium 8 Roll',
    'price': 38000.0,
    'isTrending': false,
    'emoji': '🧻',
    'color': 0xFFCFD8DC,
  },
  {
    'name': 'Susu UHT Full Cream 1L',
    'price': 18900.0,
    'isTrending': false,
    'emoji': '🥛',
    'color': 0xFFE3F2FD,
  },
];

const _community = [
  {
    'user': 'Rina S.',
    'initial': 'R',
    'avatarColor': 0xFFE57373,
    'image': 'https://i.pravatar.cc/150?u=rina',
    'time': '2 jam yang lalu di Indomaret Sudirman',
    'product': 'Indomie Goreng Special',
    'price': 3100.0,
    'upvotes': 24,
  },
  {
    'user': 'Andi W.',
    'initial': 'A',
    'avatarColor': 0xFF81C784,
    'image': null,
    'time': '5 jam yang lalu di Alfamidi Kebon Jeruk',
    'product': 'Aqua Botol 600ml',
    'price': 3500.0,
    'upvotes': 12,
  },
];

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
      body: SingleChildScrollView(
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
              'Halo, $name 👋',
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
    return GestureDetector(
      onTap: () => context.go('/scan'),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.black54, size: 20),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Cari produk atau scan...',
                style: TextStyle(color: Colors.black54, fontSize: 14),
              ),
            ),
            Icon(Icons.qr_code_scanner, color: const Color(0xFF1976D2), size: 20),
          ],
        ),
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
              'Promo Sekarang 🔥',
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
        SizedBox(
          height: 240,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: _promos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final p = _promos[i];
              return _PromoCard(promo: p, cs: cs, tt: tt);
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
        GridView.builder(
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
            return _PopularCard(product: p, cs: cs, tt: tt);
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
        Text(
          'Baru dari Komunitas',
          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        const SizedBox(height: 12),
        ListView.separated(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (c['image'] != null)
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: NetworkImage(c['image'] as String),
                        )
                      else
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Color(c['avatarColor'] as int),
                          child: Text(
                            c['initial'] as String,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c['user'] as String,
                              style: tt.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            Text(
                              c['time'] as String,
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c['product'] as String,
                                style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: Colors.black87),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _rp(c['price'] as double),
                                style: tt.bodyMedium?.copyWith(
                                  color: const Color(0xFF1976D2),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _upvoted[i] = !upvoted),
                          child: Column(
                            children: [
                              Icon(
                                upvoted ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                                size: 18,
                                color: upvoted ? const Color(0xFF1976D2) : Colors.black54,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$upvotes',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: upvoted ? const Color(0xFF1976D2) : Colors.black54,
                                ),
                              ),
                            ],
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
                    context.go('/explore');
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
  const _PromoCard({required this.promo, required this.cs, required this.tt});

  final Map<String, dynamic> promo;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image area
          Expanded(
            flex: 5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Color(promo['color'] as int),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                  ),
                  child: Center(
                    child: Text(promo['emoji'] as String, style: const TextStyle(fontSize: 48)),
                  ),
                ),
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
                      promo['discount'] as String,
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
          // Info area
          Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    promo['store'] as String,
                    style: const TextStyle(fontSize: 10, color: Colors.black54),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    promo['name'] as String,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: Colors.black87, height: 1.2),
                  ),
                  const Spacer(),
                  Text(
                    _rp(promo['discountPrice'] as double),
                    style: tt.bodyMedium?.copyWith(
                      color: const Color(0xFF1976D2),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _rp(promo['originalPrice'] as double),
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
    );
  }
}

// ─── Popular Card ─────────────────────────────────────────────────────────────
class _PopularCard extends StatelessWidget {
  const _PopularCard({required this.product, required this.cs, required this.tt});

  final Map<String, dynamic> product;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                    color: Color(product['color'] as int),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                  ),
                  child: Center(
                    child: Text(
                      product['emoji'] as String,
                      style: const TextStyle(fontSize: 48),
                    ),
                  ),
                ),
                if (product['isTrending'] as bool)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF8D6E63), // Brown
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
                    product['name'] as String,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: Colors.black87, height: 1.2),
                  ),
                  Text(
                    _rp(product['price'] as double),
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
    );
  }
}
