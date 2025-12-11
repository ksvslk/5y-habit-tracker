import 'package:flutter/material.dart';

class MosaicPainter extends CustomPainter {
  final List<String> completedDays; // Changed to List for Isar compatibility
  final int year;
  final Color tileColor;
  final double itemRadius;

  // Pre-calculate constants to save CPU cycles in the loop
  static const int cols = 20;
  static const int rows = 19; 
  static const int totalDays = 365;

  MosaicPainter({
    required this.completedDays,
    required this.year,
    required this.tileColor,
    required this.itemRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Optimization: Create Paint objects once outside the loop
    final Paint lockPaint = Paint()..color = tileColor..style = PaintingStyle.fill;
    
    // Using a simpler loop structure for raw speed
    final double cellWidth = size.width / cols;
    final double cellHeight = size.height / rows;
    const double gapDeflate = 0.5;
    
    // Optimization: Cache set lookup for O(1) access
    final Set<String> completedSet = completedDays.toSet();

    for (int i = 0; i < totalDays; i++) {
      // Logic: Only draw if NOT completed (to hide the image)
      final String key = "$year-$i";
      if (completedSet.contains(key)) continue; 

      int row = i ~/ cols;
      int col = i % cols;
      
      double width = cellWidth;
      // Handle the hanging items in the last row
      if (i == totalDays - 1) {
        int itemsInLastRow = totalDays % cols;
        if (itemsInLastRow == 0) itemsInLastRow = cols;
        int span = (cols - itemsInLastRow) + 1;
        width = cellWidth * span;
      }

      Rect cellRect = Rect.fromLTWH(col * cellWidth, row * cellHeight, width, cellHeight);
      
      // Draw the "Cover" tile
      canvas.drawRRect(
        RRect.fromRectAndRadius(cellRect.deflate(gapDeflate), Radius.circular(itemRadius)), 
        lockPaint
      );
    }
  }

  @override
  bool shouldRepaint(covariant MosaicPainter oldDelegate) {
    return oldDelegate.completedDays.length != completedDays.length || 
           oldDelegate.year != year || 
           oldDelegate.tileColor != tileColor;
  }
}