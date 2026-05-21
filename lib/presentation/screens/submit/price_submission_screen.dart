import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../data/services/gemini_service.dart';
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
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _storeController = TextEditingController();
  String? _selectedCity;
  DateTime _selectedDate = DateTime.now();
  File? _receiptImageFile;
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
    _productNameController.text = _productData?['product_name'] ?? _productData?['name'] ?? '';
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _priceController.dispose();
    _storeController.dispose();
    super.dispose();
  }

  void _calculatePoints() {
    int total = 10;
    if (_receiptImageFile != null) {
      total += 5;
    }
    setState(() {
      _estimatedPoints = total;
    });
  }

  Future<void> _pickReceiptPhoto() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(source: ImageSource.gallery);
    if (photo != null) {
      setState(() {
        _receiptImageFile = File(photo.path);
      });
      _calculatePoints();
    }
  }

  Future<void> _submitPrice() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedCity == null || _selectedCity!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kota terlebih dahulu'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = ref.read(currentUserModelProvider).value;
      if (user == null) throw Exception('User belum login. Silakan login terlebih dahulu.');

      final firestoreService = ref.read(firestoreServiceProvider);
      final storageService = StorageService();
      final geminiService = GeminiService();

      final priceValue = double.tryParse(_priceController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0;
      final productId = _productData?['id']?.toString() ?? 'unknown_product_id';
      final productName = _productNameController.text;
      final storeName = _storeController.text;

      Map<String, dynamic>? validationResult;
      try {
        validationResult = await geminiService.validateSubmission(
          productName: productName,
          submittedPrice: priceValue,
          storeName: storeName,
          receiptImage: _receiptImageFile,
        );
      } catch (e) {
        debugPrint('Gemini validation failed or timeout: $e');
        validationResult = null; // Proceed to fallback
      }

      bool isValid = false;
      int pointsAwarded = _estimatedPoints;
      double aiScore = 0.5;
      String status = 'pending';

      if (validationResult != null) {
        final validation = validationResult['validation'] as Map<String, dynamic>?;
        isValid = validation?['status'] == 'valid' || validation?['status'] == 'approved' || validation?['status'] == true || validationResult['is_valid'] == true;
        pointsAwarded = validationResult['points_awarded'] ?? _estimatedPoints;
        aiScore = validationResult['confidence_score'] ?? 1.0;
        status = isValid ? 'approved' : 'rejected';
      } else {
        isValid = true; // Fallback so we don't reject
      }

      if (isValid) {
        String submissionId = await (firestoreService as dynamic).submitPrice({
          'userId': user.id,
          'product_id': productId,
          'product_name': productName,
          'price': priceValue,
          'store_name': storeName,
          'city': _selectedCity ?? 'Unknown',
          'photo_url': null,
          'status': status,
          'ai_validation_score': aiScore,
        });

          if (_receiptImageFile != null) {
            String? photoUrl = await storageService.uploadReceiptPhoto(_receiptImageFile!, submissionId);
            if (photoUrl != null) {
               // Update foto url if upload is successful
               // For simplicity, update directly or via a service method
               await FirebaseFirestore.instance.collection('community_submissions').doc(submissionId).update({
                 'photo_url': photoUrl,
               });
            }
          }

          await firestoreService.addPoints(user.id, (pointsAwarded as num).toInt());

          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                title: const Text('Sukses!'),
                content: Text('Harga berhasil disubmit. Kamu mendapat +$pointsAwarded Poin!'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.go('/home');
                    },
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        } else {
           if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Submission ditolak: ${validationResult?['reason'] ?? 'Harga tidak valid'}"), backgroundColor: Colors.red),
            );
          }
        }
    } catch (e) {
      debugPrint('Error during submission: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal submit: $e'), backgroundColor: Colors.red),
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final String? imageUrl = _productData?['image_url'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit Harga Real'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Chip(
              backgroundColor: Colors.green.shade50,
              avatar: const Icon(Icons.monetization_on, color: Colors.amber, size: 18),
              label: Text(
                '+$_estimatedPoints Poin',
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
              Text('Nama Produk', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (imageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(imageUrl, width: 48, height: 48, fit: BoxFit.cover),
                ),
                const SizedBox(height: 8),
              ],
              TextFormField(
                controller: _productNameController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.shopping_bag),
                  hintText: "Masukkan nama produk",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => (v == null || v.isEmpty) ? "Masukkan nama produk" : null,
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
                initialValue: _selectedCity,
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
                  child: _receiptImageFile != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Image.file(_receiptImageFile!, fit: BoxFit.cover),
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
                                      _receiptImageFile = null;
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
                            '$_estimatedPoints poin',
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
                          if (_receiptImageFile != null)
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
