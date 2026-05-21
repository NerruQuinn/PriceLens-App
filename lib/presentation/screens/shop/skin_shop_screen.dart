import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../data/models/skin_model.dart';

import '../../../providers/user_provider.dart';
import '../../../providers/skin_provider.dart';
import '../../../providers/auth_provider.dart';

class SkinShopScreen extends ConsumerStatefulWidget {
  const SkinShopScreen({super.key});

  @override
  ConsumerState<SkinShopScreen> createState() => _SkinShopScreenState();
}

class _SkinShopScreenState extends ConsumerState<SkinShopScreen> {
  int _selectedTabIndex = 0;
  final List<String> _tabs = ['Semua', 'Desain Kartu', 'Tema App', 'Frame'];
  final List<String> _categories = ['all', 'card_design', 'app_theme', 'frame'];
  
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onPurchase(SkinModel skin, int userPoints, String userId) {
    if (userPoints >= skin.price) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Konfirmasi Pembelian'),
          content: Text('Apakah Anda yakin ingin membeli skin ${skin.name} seharga ${skin.price} poin?\nSisa poin Anda akan menjadi ${userPoints - skin.price}.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _processPurchase(skin, userId);
              },
              child: const Text('Beli'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Poin tidak cukup')),
      );
    }
  }

  Future<void> _processPurchase(SkinModel skin, String userId) async {
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      // Asumsi repository memilki function unlockSkin dan addPoints
      await firestoreService.unlockSkin(userId, skin.id);
      await firestoreService.addPoints(userId, -skin.price);
      
      ref.invalidate(currentUserModelProvider);
      ref.invalidate(userProvider(userId));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pembelian berhasil!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _onEquip(SkinModel skin, String userId) async {
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.setActiveSkin(userId, skin.id);
      
      ref.invalidate(currentUserModelProvider);
      ref.invalidate(userProvider(userId));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Skin diaktifkan')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserModelProvider);
    final skinsAsync = ref.watch(allSkinsProvider);

    int userPoints = 0;
    String userId = '';
    List<String> unlockedSkins = [];
    String activeSkinId = 'default';

    userAsync.whenData((user) {
      if (user != null) {
        userPoints = (user as dynamic).points as int? ?? 0;
        userId = (user as dynamic).id as String;
        unlockedSkins = List<String>.from((user as dynamic).unlockedSkins ?? ['default']);
        activeSkinId = (user as dynamic).currentSkin as String? ?? 'default';
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        title: const Text('Toko Skin'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Chip(
              avatar: const Icon(Icons.monetization_on, color: Colors.amber, size: 18),
              label: Text('$userPoints'),
              backgroundColor: Colors.amber.withValues(alpha: 0.2),
              side: BorderSide.none,
            ),
          ),
        ],
      ),
      body: skinsAsync.when(
        data: (skinsData) {
          final List<SkinModel> allSkins = List<SkinModel>.from(skinsData);
          
          final selectedCategory = _categories[_selectedTabIndex];
          final filteredSkins = selectedCategory == 'all'
              ? allSkins
              : allSkins.where((s) => s.category == selectedCategory).toList();

          final featuredSkin = allSkins.where((s) => s.isFeatured && s.featuredDeadline != null && s.featuredDeadline!.isAfter(_now)).firstOrNull;

          return Column(
            children: [
              _buildTabs(),
              Expanded(
                child: filteredSkins.isEmpty
                    ? _buildEmptyState()
                    : ListView(
                        padding: const EdgeInsets.all(16.0),
                        children: [
                          if (featuredSkin != null && _selectedTabIndex == 0) ...[
                            _buildFeaturedBanner(featuredSkin, unlockedSkins.contains(featuredSkin.id), activeSkinId == featuredSkin.id, userPoints, userId),
                            const SizedBox(height: 16),
                          ],
                          _buildGrid(filteredSkins, unlockedSkins, activeSkinId, userPoints, userId),
                        ],
                      ),
              ),
            ],
          );
        },
        loading: () => Column(
          children: [
            _buildTabs(),
            Expanded(child: _buildLoadingState()),
          ],
        ),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: List.generate(_tabs.length, (index) {
          final isSelected = _selectedTabIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(_tabs[index]),
              selected: isSelected,
              onSelected: (selected) {
                setState(() => _selectedTabIndex = index);
              },
              selectedColor: Colors.blue,
              labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.blue),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Colors.blue, width: 1),
              ),
              showCheckmark: false,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildFeaturedBanner(SkinModel skin, bool isOwned, bool isActive, int userPoints, String userId) {
    Duration remaining = skin.featuredDeadline!.difference(_now);
    if (remaining.isNegative) remaining = Duration.zero;
    final hours = remaining.inHours.toString().padLeft(2, '0');
    final minutes = (remaining.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(16),
        image: skin.thumbnailUrl != null ? DecorationImage(
          image: NetworkImage(skin.thumbnailUrl!),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.5), BlendMode.darken),
        ) : null,
      ),
      child: Stack(
        children: [
          if (skin.thumbnailUrl == null)
            Container(
              decoration: BoxDecoration(
                  color: skin.previewColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('TERBATAS!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(skin.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
                      const SizedBox(height: 4),
                      Text('$hours:$minutes:$seconds', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.monetization_on, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text('${skin.price}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildActionButton(skin, isOwned, isActive, userPoints, userId, isBanner: true),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<SkinModel> skins, List<String> unlockedSkins, String activeSkinId, int userPoints, String userId) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: skins.length,
      itemBuilder: (context, index) {
        final skin = skins[index];
        final isOwned = unlockedSkins.contains(skin.id);
        final isActive = activeSkinId == skin.id;
        return _buildSkinCard(skin, isOwned, isActive, userPoints, userId);
      },
    );
  }

  Widget _buildSkinCard(SkinModel skin, bool isOwned, bool isActive, int userPoints, String userId) {
    Color rarityColor;
    switch (skin.rarity.toLowerCase()) {
      case 'uncommon': rarityColor = Colors.green; break;
      case 'rare': rarityColor = Colors.blue; break;
      case 'epic': rarityColor = Colors.purple; break;
      case 'common':
      default: rarityColor = Colors.grey; break;
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: skin.previewColor),
                if (skin.thumbnailUrl != null)
                  Image.network(skin.thumbnailUrl!, fit: BoxFit.cover),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: rarityColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(skin.rarity.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(skin.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(skin.category, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.monetization_on, color: Colors.amber, size: 14),
                        const SizedBox(width: 4),
                        Text('${skin.price}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    _buildActionButton(skin, isOwned, isActive, userPoints, userId),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(SkinModel skin, bool isOwned, bool isActive, int userPoints, String userId, {bool isBanner = false}) {
    if (isActive) {
      return FilledButton(
        onPressed: null,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.grey,
          minimumSize: isBanner ? const Size(80, 36) : const Size(60, 28),
          padding: EdgeInsets.symmetric(horizontal: isBanner ? 16 : 8),
        ),
        child: Text('Aktif', style: TextStyle(fontSize: isBanner ? 14 : 12)),
      );
    } else if (isOwned) {
      return FilledButton(
        onPressed: () => _onEquip(skin, userId),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.green,
          minimumSize: isBanner ? const Size(80, 36) : const Size(60, 28),
          padding: EdgeInsets.symmetric(horizontal: isBanner ? 16 : 8),
        ),
        child: Text('Pakai', style: TextStyle(fontSize: isBanner ? 14 : 12)),
      );
    } else {
      return FilledButton(
        onPressed: () => _onPurchase(skin, userPoints, userId),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.blue,
          minimumSize: isBanner ? const Size(80, 36) : const Size(60, 28),
          padding: EdgeInsets.symmetric(horizontal: isBanner ? 16 : 8),
        ),
        child: Text('Beli', style: TextStyle(fontSize: isBanner ? 14 : 12)),
      );
    }
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Belum ada skin tersedia', style: TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: GridView.builder(
        padding: const EdgeInsets.all(16.0),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          );
        },
      ),
    );
  }
}
