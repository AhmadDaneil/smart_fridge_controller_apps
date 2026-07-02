import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme.dart';

/// Result returned to the caller after a successful scan + lookup.
class ScannedProduct {
  final String barcode;
  final String? name;
  final String? brand;
  final String? imageUrl;
  const ScannedProduct({required this.barcode, this.name, this.brand, this.imageUrl});
}

/// Full-screen camera barcode scanner.
/// Push this and await the result:
///
/// ```dart
/// final result = await Navigator.push<ScannedProduct>(
///   context, MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()));
/// ```
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false; // prevents firing multiple times per scan burst
  bool _looking = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null) return;

    setState(() {
      _handled = true;
      _looking = true;
    });
    await _controller.stop();

    String? productName;
    String? brand;
    String? imageUrl;
    try {
      // Open Food Facts is a free, no-key-required product database.
      final res = await http.get(Uri.parse(
          'https://world.openfoodfacts.org/api/v2/product/$code.json'
          '?fields=product_name,brands,image_front_url,image_url'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 1) {
          final product = data['product'] as Map<String, dynamic>?;
          productName = product?['product_name'] as String?;
          brand = product?['brands'] as String?; // e.g. "Nestlé, Milo"
          imageUrl = (product?['image_front_url'] ?? product?['image_url']) as String?;
        }
      }
    } catch (_) {
      // Network issue or product not found — fall back to barcode-only.
    }

    if (mounted) {
      Navigator.pop(
        context,
        ScannedProduct(
          barcode: code,
          name: (productName?.isNotEmpty ?? false) ? productName : null,
          brand: (brand?.isNotEmpty ?? false) ? brand!.split(',').first.trim() : null,
          imageUrl: (imageUrl?.isNotEmpty ?? false) ? imageUrl : null,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, state, child) {
                return Icon(
                  state.torchState == TorchState.on
                      ? Icons.flash_on_rounded
                      : Icons.flash_off_rounded,
                );
              },
            ),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),

          // Scan window overlay
          Container(
            width: 260,
            height: 180,
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.primary, width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
          ),

          if (_looking)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 12),
                    Text('Looking up product…', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),

          Positioned(
            bottom: 32,
            child: Text(
              'Align barcode within the frame',
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}