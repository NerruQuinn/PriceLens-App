import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isProcessing = false;
  int _selectedTab = 0; // 0=Foto Produk, 1=Scan Barcode, 2=Keranjang
  final BarcodeScanner _barcodeScanner = BarcodeScanner();

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        _controller = CameraController(_cameras[0], ResolutionPreset.high);
        await _controller!.initialize();
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error initializing camera: \$e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _barcodeScanner.close();
    super.dispose();
  }

  Future<void> _captureAndAnalyze() async {
    if (_isProcessing || _controller == null || !_controller!.value.isInitialized) return;
    setState(() {
      _isProcessing = true;
    });

    try {
      final XFile photo = await _controller!.takePicture();
      final Uint8List bytes = await photo.readAsBytes();

      if (!mounted) return;

      if (_selectedTab == 0) {
        context.go('/result', extra: {'imageBytes': bytes, 'type': 'product'});
      } else if (_selectedTab == 2) {
        context.go('/basket', extra: {'imageBytes': bytes});
      }
    } catch (e) {
      debugPrint('Error capturing photo: \$e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _scanBarcodeFromCamera() async {
    if (_isProcessing || _controller == null || !_controller!.value.isInitialized) return;
    setState(() {
      _isProcessing = true;
    });

    try {
      final XFile photo = await _controller!.takePicture();
      final InputImage inputImage = InputImage.fromFilePath(photo.path);
      
      final List<Barcode> barcodes = await _barcodeScanner.processImage(inputImage);
      
      if (!mounted) return;

      if (barcodes.isNotEmpty) {
        final barcode = barcodes.first;
        if (barcode.rawValue != null) {
          context.go('/result', extra: {'barcode': barcode.rawValue, 'type': 'barcode'});
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Barcode tidak ditemukan')),
        );
      }
    } catch (e) {
      debugPrint('Error scanning barcode: \$e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image != null) {
        final Uint8List bytes = await image.readAsBytes();
        if (!mounted) return;

        if (_selectedTab == 1) {
          final InputImage inputImage = InputImage.fromFilePath(image.path);
          final List<Barcode> barcodes = await _barcodeScanner.processImage(inputImage);
          if (!mounted) return;
          if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
            context.go('/result', extra: {'barcode': barcodes.first.rawValue, 'type': 'barcode'});
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Barcode tidak ditemukan')),
            );
          }
        } else if (_selectedTab == 0) {
          context.go('/result', extra: {'imageBytes': bytes, 'type': 'product'});
        } else if (_selectedTab == 2) {
          context.go('/basket', extra: {'imageBytes': bytes});
        }
      }
    } catch (e) {
      debugPrint('Error picking from gallery: \$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full screen CameraPreview
          if (_isInitialized && _controller != null)
            SizedBox.expand(
              child: CameraPreview(_controller!),
            ),
            
          // Overlay gelap semi-transparent
          Container(
            color: Colors.black54,
          ),
          
          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                  const Text(
                    'Scan Produk',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.flash_on, color: Colors.white),
                    onPressed: () {
                      // Toggle flash
                    },
                  ),
                ],
              ),
            ),
          ),
          
          // Center AnimatedContainer scan frame
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 280,
              height: _selectedTab == 1 ? 160 : 280,
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.primary, width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          
          // Bottom sheet
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: DefaultTabController(
                length: 3,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TabBar(
                      onTap: (index) {
                        setState(() {
                          _selectedTab = index;
                        });
                      },
                      labelColor: colorScheme.primary,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: colorScheme.primary,
                      tabs: const [
                        Tab(text: 'Foto Produk'),
                        Tab(text: 'Scan Barcode'),
                        Tab(text: 'Keranjang'),
                      ],
                    ),
                    SizedBox(
                      height: 160,
                      child: TabBarView(
                        physics: const NeverScrollableScrollPhysics(), // Handle tab changes via onTap
                        children: [
                          // Tab 0: Foto Produk
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.photo_library, size: 32),
                                    onPressed: _pickFromGallery,
                                  ),
                                  const SizedBox(width: 24),
                                  GestureDetector(
                                    onTap: _captureAndAnalyze,
                                    child: CircleAvatar(
                                      radius: 36,
                                      backgroundColor: colorScheme.primary,
                                      child: _isProcessing
                                          ? const CircularProgressIndicator(color: Colors.white)
                                          : const Icon(Icons.camera_alt, color: Colors.white, size: 36),
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  const SizedBox(width: 32), // Placeholder for balance
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Arahkan kamera ke produk',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                          
                          // Tab 1: Scan Barcode
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Arahkan ke barcode produk', textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              if (_isProcessing)
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 48.0),
                                  child: LinearProgressIndicator(),
                                )
                              else ...[
                                ElevatedButton.icon(
                                  onPressed: _scanBarcodeFromCamera,
                                  icon: const Icon(Icons.qr_code_scanner),
                                  label: const Text('Scan Barcode'),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: _pickFromGallery,
                                  child: const Text('Scan dari Galeri'),
                                ),
                              ],
                            ],
                          ),
                          
                          // Tab 2: Keranjang
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Foto seluruh isi keranjang belanjamu',
                                style: TextStyle(fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'AI akan mengenali semua produk sekaligus',
                                style: TextStyle(color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _captureAndAnalyze,
                                icon: _isProcessing 
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Icon(Icons.camera_alt),
                                label: const Text('Foto Keranjang'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorScheme.primary,
                                  foregroundColor: colorScheme.onPrimary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
