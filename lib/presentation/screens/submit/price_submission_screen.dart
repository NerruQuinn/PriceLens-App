import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../data/models/submission_model.dart';
import '../../../data/models/price_entry_model.dart';
import '../../../data/services/gemini_service.dart';
import '../../../data/services/firestore_service.dart';
import '../../../data/services/storage_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/user_provider.dart';

class PriceSubmissionScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? extra;

  const PriceSubmissionScreen({super.key, this.extra});

  @override
  ConsumerState<PriceSubmissionScreen> createState() => _PriceSubmissionScreenState();
}

class _PriceSubmissionScreenState extends ConsumerState<PriceSubmissionScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _storeController = TextEditingController();
  String? _selectedCity;
  DateTime _selectedDate = DateTime.now();
  Uint8List? _receiptImageBytes;
  bool _isSubmitting = false;
  Map<String, dynamic>? _productData;
  int _estimatedPoints = 10;

  final List<String> _suggestedStores = ["Indomaret", "Alfamart", "Superindo", "Tokopedia", "Shopee"];
  final List<String> _cities = [
    "Jakarta", "Surabaya", "Bandung", "Medan", "Makassar",
    "Semarang", "Palembang", "Tangerang", "Depok", "Ambon",
    "Manado", "Balikpapan", "Lainnya"
  ];

  @override
  void initState() {
    super.initState();
    _productData = widget.extra;
  }

  @override
  void dispose() {
    _priceController.dispose();
    _storeController.dispose();
    super.dispose();
  }

  void _calculatePoints() {
    int total = 10;
    if (_receiptImageBytes != null) {
      total += 5;
    }
    setState(() {
      _estimatedPoints = total;
    });
  }

  Future<void> _pickReceiptPhoto() async {
    final picker = ImagePicker();
    // Biarkan user memilih camera atau galeri via dialog sederhana (opsional), 
    // disini kita gunakan camera langsung untuk kecepatan, atau tampilkan dialog.
    // Sesuai prompt: ImageSource.gallery atau camera. Kita pakai gallery.
    final photo = await picker.pickImage(source: ImageSource.gallery);
    if (photo != null) {
      final bytes = await photo.readAsBytes();
      setState(() {
        _receiptImageBytes = bytes;
      });
      _calculatePoints();
    }
  }

  Future<void> _submitPrice() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = ref.read(currentUserModelProvider).value;
      if (user == null) throw Exception('User not logged in');

      final firestoreService = ref.read(firestoreServiceProvider);
      final storageService = StorageService();
      final geminiService = GeminiService();

      String? photoUrl;
      if (_receiptImageBytes != null) {
        photoUrl = await storageService.uploadReceiptPhoto(_receiptImageBytes!, user.id);
      }

      final priceValue = double.tryParse(_priceController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0;
      final productId = _productData?['id']?.toString() ?? 'unknown_product_id';
      final productName = _productData?['product_name'] ?? _productData?['name'] ?? 'Unknown Product';
      final storeName = _storeController.text;

      final submissionId = DateTime.now().millisecondsSinceEpoch.toString() + user.id.substring(0, 3);
      
      final submission = SubmissionModel(
        id: submissionId,
        userId: user.id,
        productId: productId,
        price: priceValue,
        storeName: storeName,
        city: _selectedCity ?? 'Unknown',
        photoUrl: photoUrl,
        status: 'pending',
        aiValidationScore: 0.0,
        upvotes: 0,
        upvotedBy: const [],
        timestamp: DateTime.now(),
      );

      // Call firestoreService.createSubmission()
      await (firestoreService as dynamic).createSubmission(submission);

      // Award points via firestoreService.addPoints()
      await firestoreService.addPoints(user.id, _estimatedPoints);

      // Call geminiService.validateSubmission() di background
      _runBackgroundValidation(
        geminiService: geminiService,
        firestoreService: firestoreService,
        submission: submission,
        productName: productName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Berhasil disubmit! Kamu mendapat +$_estimatedPoints Poin'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal submit: \$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _runBackgroundValidation({
    required GeminiService geminiService,
    required dynamic firestoreService,
    required SubmissionModel submission,
    required String productName,
  }) async {
    try {
      final validationResult = await geminiService.validateSubmission(
        productName: productName,
        submittedPrice: submission.price,
        storeName: submission.storeName,
        receiptImage: _receiptImageBytes,
      );

      if (validationResult != null) {
        final isValid = validationResult['is_valid'] == true;
        final score = (validationResult['confidence_score'] ?? 0).toDouble();

        final updatedSubmission = submission.copyWith(
          status: isValid ? 'approved' : 'rejected',
          aiValidationScore: score,
        );

        await firestoreService.updateSubmission(updatedSubmission);
        
        if (isValid) {
          final priceEntry = PriceEntryModel(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            productId: submission.productId,
            price: submission.price,
            storeName: submission.storeName,
            city: submission.city,
            source: 'community',
            photoUrl: submission.photoUrl,
            submittedBy: submission.userId,
            validationStatus: 'approved',
            upvotes: 0,
            timestamp: DateTime.now(),
          );
          await firestoreService.addPriceEntry(submission.productId, priceEntry);
        }
      }
    } catch (e) {
      debugPrint('Background validation error: \$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final String productName = _productData?['product_name'] ?? _productData?['name'] ?? 'Pilih Produk';
    final String brandStr = _productData?['brand'] ?? 'Unknown Brand';
    final String categoryStr = _productData?['category'] ?? 'Category';
    final String? imageUrl = _productData?['image_url'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit Harga Real'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Chip(
              backgroundColor: Colors.green.shade50,
              avatar: const Icon(Icons.monetization_on, color: Colors.amber, size: 18),
              label: Text(
                '+\$_estimatedPoints Poin',
                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              ),
              side: BorderSide.none,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // a) PRODUCT SECTION
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: ListTile(
                  leading: imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(imageUrl, width: 48, height: 48, fit: BoxFit.cover),
                        )
                      : Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.shopping_bag, color: colorScheme.onPrimaryContainer),
                        ),
                  title: Text(productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('$brandStr • $categoryStr'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      // Logic untuk ganti produk
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // b) HARGA FIELD
              Text('Harga yang Kamu Temukan', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixText: "Rp ",
                  hintText: "0",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                ),
                validator: (v) => (v == null || v.isEmpty) ? "Masukkan harga" : null,
                style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary),
              ),
              const SizedBox(height: 24),

              // c) TOKO FIELD
              Text('Nama Toko', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _storeController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.store),
                  hintText: "Contoh: Indomaret, Alfamart, Tokopedia...",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => (v == null || v.isEmpty) ? "Masukkan nama toko" : null,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _suggestedStores.map((store) => ActionChip(
                  label: Text(store),
                  onPressed: () {
                    _storeController.text = store;
                  },
                )).toList(),
              ),
              const SizedBox(height: 24),

              // d) KOTA FIELD
              Text('Kota/Kabupaten', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedCity,
                items: _cities.map((city) => DropdownMenuItem(
                  value: city,
                  child: Text(city),
                )).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCity = value;
                  });
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  hintText: 'Pilih kota',
                ),
                validator: (v) => v == null ? "Pilih kota" : null,
              ),
              const SizedBox(height: 24),

              // e) TANGGAL FIELD
              Text('Tanggal', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() {
                      _selectedDate = date;
                    });
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Colors.grey),
                      const SizedBox(width: 12),
                      Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
                      const Spacer(),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // f) FOTO BUKTI SECTION
              Text('Foto Struk/Label Harga', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('+5 Poin Bonus dengan foto bukti!', style: TextStyle(color: Colors.green, fontSize: 12)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickReceiptPhoto,
                child: Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border.all(color: Colors.grey.shade400, width: 1.5), // Optional: wrap with dotted_border package if added later
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _receiptImageBytes != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Image.memory(_receiptImageBytes!, fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: CircleAvatar(
                                backgroundColor: Colors.black54,
                                child: IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      _receiptImageBytes = null;
                                    });
                                    _calculatePoints();
                                  },
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey),
                            const SizedBox(height: 8),
                            const Text('Upload Foto Struk atau Label Harga'),
                            Text('JPG, PNG maksimal 5MB', style: textTheme.bodySmall?.copyWith(color: Colors.grey)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // g) POINT PREVIEW CARD
              Card(
                color: colorScheme.primaryContainer,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.monetization_on, color: Colors.amber, size: 32),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Estimasi Poin Kamu', style: textTheme.titleMedium),
                          Text(
                            '\$_estimatedPoints poin',
                            style: textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('10 base poin'),
                          if (_receiptImageBytes != null)
                            const Text('+5 foto bonus', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // h) SUBMIT BUTTON
              SizedBox(
                height: 56,
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submitPrice,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 24, width: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.send),
                            SizedBox(width: 8),
                            Text('Submit & Dapatkan Poin', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }
}
