import 'dart:io';
import 'package:flutter/material.dart';

class BeforeAfterSlider extends StatefulWidget {
  final String beforeImagePath;
  final String afterImagePath;

  const BeforeAfterSlider({
    super.key,
    required this.beforeImagePath,
    required this.afterImagePath,
  });

  @override
  State<BeforeAfterSlider> createState() => _BeforeAfterSliderState();
}

class _BeforeAfterSliderState extends State<BeforeAfterSlider> {
  double _dividerPosition = 0.5; // 0.0 ile 1.0 arasında

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return Stack(
          fit: StackFit.expand,
          children: [
            // 1. Yeni Fotoğraf (After - Altta Tam Boyut)
            Image.file(
              File(widget.afterImagePath),
              fit: BoxFit.contain,
              width: width,
              height: height,
            ),

            // 2. Eski Fotoğraf (Before - Soldan Kırpılmış Katman)
            ClipRect(
              clipper: _HorizontalClipper(_dividerPosition * width),
              child: Image.file(
                File(widget.beforeImagePath),
                fit: BoxFit.contain,
                width: width,
                height: height,
              ),
            ),

            // 3. Ortadaki Kaydırma Çizgisi ve Tutamaç
            Positioned(
              left: _dividerPosition * width - 15,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _dividerPosition += details.delta.dx / width;
                    _dividerPosition = _dividerPosition.clamp(0.0, 1.0);
                  });
                },
                child: SizedBox(
                  width: 30,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(width: 2.5, color: Colors.white),
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.amber.shade700,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(color: Colors.black45, blurRadius: 4),
                          ],
                        ),
                        child: const Icon(Icons.compare_arrows, size: 18, color: Colors.black),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 4. Etiketler
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                child: const Text("Orijinal", style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                child: const Text("Yeni", style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HorizontalClipper extends CustomClipper<Rect> {
  final double clipWidth;
  _HorizontalClipper(this.clipWidth);

  @override
  Rect getClip(Size size) => Rect.fromLTRB(0, 0, clipWidth, size.height);

  @override
  bool shouldReclip(_HorizontalClipper oldClipper) => oldClipper.clipWidth != clipWidth;
}