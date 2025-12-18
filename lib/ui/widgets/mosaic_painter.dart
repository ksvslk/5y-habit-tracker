import 'package:flutter/material.dart';

class MosaicPainter extends CustomPainter {
  final List<String> completedDays;
  final int year;
  final Color fillColor;
  final Color borderColor;

  static const int cols = 20;
  static const int rows = 19; 
  static const int totalDays = 365;

  MosaicPainter({
    required this.completedDays,
    required this.year,
    required this.fillColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final Paint innerBorderPaint = Paint()
      ..color = borderColor
      ..strokeCap = StrokeCap.butt
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0; // Inner grid lines stay thin

    // NEW: Paint for the Outer Edge
    final Paint outerBorderPaint = Paint()
      ..color = borderColor // Or make this darker/thicker if you want
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.0; // <--- THICKER OUTER EDGE

    final double cellWidth = size.width / cols;
    final double cellHeight = size.height / rows;
    
    final Set<String> completedSet = completedDays.toSet();

    // 1. Draw the cells and inner grid
    for (int i = 0; i < totalDays; i++) {
      final String key = "$year-$i";
      if (completedSet.contains(key)) continue; 

      int row = i ~/ cols;
      int col = i % cols;
      
      double width = cellWidth;
      if (i == totalDays - 1) {
        int itemsInLastRow = totalDays % cols;
        if (itemsInLastRow == 0) itemsInLastRow = cols;
        int span = (cols - itemsInLastRow) + 1;
        width = cellWidth * span;
      }

      Rect cellRect = Rect.fromLTWH(col * cellWidth, row * cellHeight, width, cellHeight);

      canvas.drawRect(cellRect, fillPaint);
      canvas.drawRect(cellRect, innerBorderPaint);
    }

    // 2. Draw the Outer Border around the whole thing
    // We deflate by 1.5 (half of 3.0) to ensure the thick line isn't clipped
    final Rect outerRect = Rect.fromLTWH(0, 0, size.width, size.height).deflate(0);
    canvas.drawRect(outerRect, outerBorderPaint);
  }

  @override
  bool shouldRepaint(covariant MosaicPainter oldDelegate) {
    return oldDelegate.completedDays.length != completedDays.length || 
           oldDelegate.year != year || 
           oldDelegate.fillColor != fillColor;
  }
}