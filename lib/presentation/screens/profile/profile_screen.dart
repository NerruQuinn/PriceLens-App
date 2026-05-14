import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../../../providers/auth_provider.dart';

import '../../../providers/submission_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {

  Color _getBadgeColor(String badge) {
    switch (badge.toLowerCase()) {
      case 'bronze': return Colors.brown;
      case 'silver': return Colors.grey.shade400;
      case 'gold': return Colors.amber;
      case 'legend': return Colors.purple;
      default: return Colors.brown;
    }
  }

  IconData _getBadgeIcon(String badge) {
    switch (badge.toLowerCase()) {
      case 'bronze': return Icons.shield;
      case 'silver': return Icons.shield_moon;
      case 'gold': return Icons.workspace_premium;
      case 'legend': return Icons.auto_awesome;
      default: return Icons.shield;
    }
  }

  int _getNextBadgeThreshold(String badge) {
    switch (badge.toLowerCase()) {
      case 'bronze': return 100;
      case 'silver': return 500;
      case 'gold': return 2000;
      case 'legend': return 99999;
      default: return 100;
    }
  }

  String _getNextBadgeName(String badge) {
    switch (badge.toLowerCase()) {
      case 'bronze': return 'Silver';
      case 'silver': return 'Gold';
      case 'gold': return 'Legend';
      case 'legend': return 'Max';
      default: return 'Silver';
    }
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.notifications),
                title: const Text('Notifikasi'),
                trailing: Switch(value: true, onChanged: (v) {}),
              ),
              ListTile(
                leading: const Icon(Icons.dark_mode),
                title: const Text('Dark Mode'),
                trailing: Switch(value: false, onChanged: (v) {}),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Keluar', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context); // close sheet
                  final authService = ref.read(authServiceProvider);
                  final router = GoRouter.of(context);
                  await authService.signOut();
                  if (mounted) router.go('/login');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final userAsync = ref.watch(currentUserModelProvider);
    
    return Scaffold(
      body: userAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Silakan login kembali'));
          }

          final badge = (user as dynamic).badge?.toString() ?? 'bronze';
          final badgeColor = _getBadgeColor(badge);
          final submissionsCount = (user as dynamic).submissionsCount as int? ?? 0;
          final points = (user as dynamic).points as int? ?? 0;
          
          final approvedCount = (submissionsCount * 0.8).toInt(); // Mock 
          final totalUpvotes = points ~/ 2; // Mock
          
          final nextBadgeThreshold = _getNextBadgeThreshold(badge);
          final currentBadge = badge.toUpperCase();
          final nextBadge = _getNextBadgeName(badge).toUpperCase();
          final progress = points / nextBadgeThreshold;
          
          final activeSkin = (user as dynamic).currentSkin?.toString() ?? 'default';
          final unlockedSkins = (user as dynamic).unlockedSkins as List<dynamic>? ?? ['default'];

          final submissionsAsync = ref.watch(userSubmissionsProvider(user.id));

          return CustomScrollView(
            slivers: [
              // a) SliverAppBar
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: _showSettingsSheet,
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colorScheme.primary, colorScheme.primaryContainer],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: colorScheme.surface,
                                backgroundImage: (user as dynamic).photoUrl != null
                                    ? CachedNetworkImageProvider((user as dynamic).photoUrl!)
                                    : null,
                                child: (user as dynamic).photoUrl == null
                                    ? Icon(Icons.person, size: 50, color: colorScheme.primary)
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: badgeColor,
                                  child: Icon(_getBadgeIcon(badge), size: 16, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            (user as dynamic).displayName ?? 'User',
                            style: textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Chip(
                            avatar: Icon(_getBadgeIcon(badge), size: 16, color: Colors.white),
                            label: Text(currentBadge),
                            backgroundColor: badgeColor.withValues(alpha: 0.3),
                            labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            side: BorderSide.none,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.monetization_on, color: Colors.amber, size: 20),
                              const SizedBox(width: 4),
                              Text(
                                '\$points Poin',
                                style: textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // b) STATS ROW
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      _buildStatCard(submissionsCount.toString(), 'Submission', colorScheme, textTheme),
                      _buildStatCard(approvedCount.toString(), 'Disetujui', colorScheme, textTheme),
                      _buildStatCard(totalUpvotes.toString(), 'Upvotes', colorScheme, textTheme),
                    ],
                  ),
                ),
              ),

              // c) PROGRESS TO NEXT BADGE
              SliverToBoxAdapter(
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Progress ke Badge Berikutnya', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(currentBadge),
                            const Spacer(),
                            Text(nextBadge),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          borderRadius: BorderRadius.circular(8),
                          minHeight: 12,
                          backgroundColor: Colors.grey.shade200,
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '\${nextBadgeThreshold - points} poin lagi',
                            style: textTheme.bodySmall?.copyWith(color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // d) SKIN AKTIF
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Skin Aktif', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          const Spacer(),
                          TextButton(
                            onPressed: () => context.go('/shop'),
                            child: const Text('Ganti'),
                          ),
                        ],
                      ),
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Container(
                          height: 100,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [colorScheme.secondaryContainer, colorScheme.tertiaryContainer],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text('PriceLens Card'),
                                      Text(activeSkin.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('Active', style: TextStyle(color: Colors.white, fontSize: 10)),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.style_outlined, size: 64, color: colorScheme.onSecondaryContainer.withValues(alpha: 0.5)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // e) KOLEKSI SKIN
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Koleksi Kamu', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.8,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: unlockedSkins.length,
                        itemBuilder: (context, index) {
                          final skin = unlockedSkins[index].toString();
                          final isActive = skin == activeSkin;
                          return Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [colorScheme.primary.withValues(alpha: 0.7), colorScheme.secondary.withValues(alpha: 0.7)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    skin.toUpperCase(),
                                    style: textTheme.bodySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              if (isActive)
                                const Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Icon(Icons.check_circle, color: Colors.green, size: 20),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // f) RIWAYAT SUBMISSION
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Riwayat Submission', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      submissionsAsync.when(
                        data: (submissions) {
                          if (submissions.isEmpty) {
                            return const Center(child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Text('Belum ada riwayat submission', style: TextStyle(color: Colors.grey)),
                            ));
                          }
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: submissions.length,
                            itemBuilder: (context, index) {
                              final sub = submissions[index];
                              final isApproved = sub.status == 'approved';
                              final isPending = sub.status == 'pending';
                              
                              Color statusColor = Colors.red;
                              if (isApproved) statusColor = Colors.green;
                              if (isPending) statusColor = Colors.amber;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(sub.productId), // ideally we resolve product name here
                                  subtitle: Text('${sub.storeName} • ${DateFormat('dd MMM yyyy').format(sub.timestamp)}'),
                                  trailing: Chip(
                                    label: Text(sub.status.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                                    backgroundColor: statusColor,
                                    padding: EdgeInsets.zero,
                                    side: BorderSide.none,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (error, stack) => Center(child: Text('Error: \$error')),
                      ),
                    ],
                  ),
                ),
              ),

              // g) BOTTOM PADDING
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: \$error')),
      ),
    );
  }

  Widget _buildStatCard(String value, String label, ColorScheme colorScheme, TextTheme textTheme) {
    return Expanded(
      child: Card(
        elevation: 0,
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            children: [
              Text(
                value,
                style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary),
              ),
              const SizedBox(height: 4),
              Text(label, style: textTheme.bodySmall?.copyWith(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
