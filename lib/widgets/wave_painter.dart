import 'dart:math';
import 'package:flutter/material.dart';

class WavePainter extends CustomPainter {
  final double p1, p2, p3;
  const WavePainter(this.p1, this.p2, this.p3);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    void wave(double phase, Color color, double yBase, double amp) {
      final path = Path()..moveTo(0, h);
      for (double x = 0; x <= w; x++) {
        final y = yBase + amp * (0.6 * sin(2 * pi * (x / w) + phase)
                                + 0.4 * sin(4 * pi * (x / w) + phase * 1.3));
        x == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      path..lineTo(w, h)..close();
      canvas.drawPath(path, Paint()..color = color);
    }
    wave(p1, const Color(0x12B07FE8), h * 0.60, h * 0.06);
    wave(p2, const Color(0x0E6B8FBA), h * 0.68, h * 0.05);
    wave(p3, const Color(0x0B7EB8A4), h * 0.75, h * 0.04);
  }

  @override
  bool shouldRepaint(WavePainter o) => o.p1 != p1 || o.p2 != p2 || o.p3 != p3;
}