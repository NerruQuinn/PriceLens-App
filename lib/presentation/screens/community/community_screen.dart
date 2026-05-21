import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../data/services/user_service.dart';

final _rupiahFmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
String _rp(double v) => _rupiahFmt.format(v);

String _timeAgo(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
  if (diff.inHours < 24) return '${diff.inHours} jam lalu';
  return '${diff.inDays} hari lalu';
}

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  String _filter = 'approved';
  List<Map<String, dynamic>> _submissions = [];
  bool _isLoading = true;
  int _limit = 10;
  final _userService = UserService();

  @override
  void initState() {
    super.initState();
    _fetchSubmissions();
  }

  Future<void> _fetchSubmissions() async {
    setState(() => _isLoading = true);
    try {
      Query query = FirebaseFirestore.instance.collection('community_submissions');
      if (_filter != 'all') {
        query = query.where('status', isEqualTo: _filter);
      }
      final snap = await query.limit(_limit).get();

      final docs = snap.docs.map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>}).toList();
      docs.sort((a, b) {
        final tA = a['timestamp'] as Timestamp?;
        final tB = b['timestamp'] as Timestamp?;
        if (tA == null || tB == null) return 0;
        return tB.compareTo(tA);
      });

      // Fetch display names
      final List<Map<String, dynamic>> enriched = [];
      for (final doc in docs) {
        final userId = doc['userId'] as String? ?? '';
        final name = userId.isNotEmpty ? await _userService.getDisplayName(userId) : 'Pengguna PriceLens';
        final initial = name.length >= 2
            ? name.substring(0, 2).toUpperCase()
            : name.isNotEmpty
                ? name[0].toUpperCase()
                : 'PL';
        final ts = doc['timestamp'] as Timestamp?;
        enriched.add({
          ...doc,
          'displayName': name,
          'initial': initial,
          'timeStr': ts != null ? _timeAgo(ts.toDate()) : 'Baru saja',
        });
      }

      if (!mounted) return;
      setState(() {
        _submissions = enriched;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _upvote(String docId) async {
    await FirebaseFirestore.instance
        .collection('community_submissions')
        .doc(docId)
        .update({'upvotes': FieldValue.increment(1)});
    _fetchSubmissions();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAFAFA),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black54),
          onPressed: () => context.go('/home'),
        ),
        title: Text(
          'Komunitas Harga',
          style: tt.titleMedium?.copyWith(
            color: const Color(0xFF1976D2),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchSubmissions,
        child: Column(
          children: [
            // Filter chips
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _chip('Semua', 'all'),
                    const SizedBox(width: 8),
                    _chip('Disetujui', 'approved'),
                    const SizedBox(width: 8),
                    _chip('Pending', 'pending'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _submissions.isEmpty
                      ? ListView(
                          children: const [
                            Padding(
                              padding: EdgeInsets.all(48),
                              child: Center(
                                child: Text('Belum ada submission.', style: TextStyle(color: Colors.black45)),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: _submissions.length + 1,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            if (i == _submissions.length) {
                              return TextButton(
                                onPressed: () {
                                  _limit += 10;
                                  _fetchSubmissions();
                                },
                                child: const Text('Muat Lebih Banyak'),
                              );
                            }
                            return _buildCard(_submissions[i]);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String value) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _filter = value);
        _fetchSubmissions();
      },
      selectedColor: const Color(0xFF1976D2),
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.black87,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 13,
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final status = item['status'] as String? ?? 'pending';
    final price = (item['price'] as num?)?.toDouble() ?? 0.0;
    final upvotes = (item['upvotes'] as num?)?.toInt() ?? 0;
    final statusColor = status == 'approved' ? Colors.green : Colors.orange;

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
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF1976D2),
                child: Text(
                  item['initial'] as String,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['displayName'] as String,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Text(
                      item['timeStr'] as String,
                      style: const TextStyle(fontSize: 11, color: Colors.black45),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status == 'approved' ? 'Disetujui' : 'Pending',
                  style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item['product_name'] as String? ?? 'Produk',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            '${item['store_name'] ?? 'Toko'} • ${item['city'] ?? ''}',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _rp(price),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1976D2),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.thumb_up_alt_outlined, size: 18, color: Colors.black45),
                    onPressed: () => _upvote(item['id'] as String),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 4),
                  Text('$upvotes', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
