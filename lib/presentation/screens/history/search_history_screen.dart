import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../providers/auth_provider.dart';
import '../../../data/models/basket_model.dart';

class SearchHistoryScreen extends ConsumerWidget {
  const SearchHistoryScreen({super.key});

  DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserModelProvider);
    final user = userAsync.value;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Riwayat Belanja',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('baskets')
                  .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Terjadi kesalahan: ${snapshot.error}', style: const TextStyle(color: Colors.black54)),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => context.go('/home'),
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4285F4)),
                          child: const Text('Home'),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allDocs = snapshot.data?.docs ?? [];
                final userBaskets = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>?;
                  return data != null;
                }).toList();

                userBaskets.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime = _parseDate(aData['createdAt']);
                  final bTime = _parseDate(bData['createdAt']);
                  return bTime.compareTo(aTime);
                });

                if (userBaskets.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'Belum ada riwayat estimasi belanja',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: userBaskets.length,
                  itemBuilder: (context, index) {
                    final data = userBaskets[index].data() as Map<String, dynamic>;
                    final basket = BasketModel.fromMap(data..['id'] = userBaskets[index].id);

                    final date = DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(_parseDate(data['createdAt']));
                    final totalEstimate = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(basket.totalEstimate);
                    final itemsCount = basket.items.length;
                    
                    String cheapestStore = "Belum ada";
                    final Map<String, double> storeTotals = {};
                    for (var item in basket.items) {
                      final store = item.cheapestStore.isNotEmpty ? item.cheapestStore : "Unknown";
                      storeTotals[store] = (storeTotals[store] ?? 0) + item.subtotal;
                    }
                    if (storeTotals.isNotEmpty) {
                      final sortedStores = storeTotals.entries.toList()
                        ..sort((a, b) => a.value.compareTo(b.value));
                      cheapestStore = sortedStores.first.key;
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      color: Colors.white,
                      clipBehavior: Clip.antiAlias,
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.all(16),
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade500),
                                  const SizedBox(width: 6),
                                  Text(
                                    date,
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Total Estimasi',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                totalEstimate,
                                style: const TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4285F4).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '$itemsCount Item',
                                      style: const TextStyle(
                                        color: Color(0xFF4285F4),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Termurah: $cheapestStore',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          children: [
                            Container(
                              color: const Color(0xFFF8F9FA),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Column(
                                children: basket.items.map((item) {
                                  final itemPrice = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(item.unitPriceEstimate);
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${item.quantity}x ', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4285F4))),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(item.name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                                              Text(item.cheapestStore, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                                            ],
                                          ),
                                        ),
                                        Text(itemPrice, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
