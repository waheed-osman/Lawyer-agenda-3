import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/utils.dart';

/// قارئ باركود / QR: يعيد النص المقروء عبر Navigator.pop، أو null عند الإلغاء.
class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({super.key});
  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  final _ctrl = MobileScannerController();
  bool _done = false;

  void _finish(String? v) {
    if (_done || v == null || v.trim().isEmpty) return;
    _done = true;
    Navigator.pop(context, v.trim());
  }

  Future<void> _fromImage() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (x == null) return;
      final r = await _ctrl.analyzeImage(x.path);
      final v = r?.barcodes.isEmpty ?? true ? null : r!.barcodes.first.rawValue;
      if (v == null) {
        if (mounted) toast(context, 'لم يُعثر على باركود في الصورة');
      } else {
        _finish(v);
      }
    } catch (_) {
      if (mounted) toast(context, 'تعذّر قراءة الصورة');
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مسح الباركود'), actions: [
        IconButton(
          tooltip: 'الفلاش',
          icon: const Icon(Icons.flashlight_on_outlined),
          onPressed: () => _ctrl.toggleTorch(),
        ),
        IconButton(
          tooltip: 'من صورة',
          icon: const Icon(Icons.image_outlined),
          onPressed: _fromImage,
        ),
      ]),
      body: Stack(children: [
        MobileScanner(
          controller: _ctrl,
          onDetect: (cap) {
            for (final b in cap.barcodes) {
              if ((b.rawValue ?? '').isNotEmpty) {
                _finish(b.rawValue);
                break;
              }
            }
          },
          errorBuilder: (c, e, _) => const Center(
              child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('تعذّر تشغيل الكاميرا. تأكد من السماح للتطبيق باستخدام الكاميرا من إعدادات الهاتف، '
                'أو استخدم زر "من صورة" بالأعلى.',
                textAlign: TextAlign.center),
          )),
        ),
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3), borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const Positioned(
          bottom: 32,
          left: 0,
          right: 0,
          child: Text('وجّه الكاميرا نحو الباركود', textAlign: TextAlign.center, style: TextStyle(color: Colors.white)),
        ),
      ]),
    );
  }
}
