import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

// --- Main execution function ---
void main() {
  print('\n🔵 Starting Auto-Generator (Vapor/Tinted White Mode)...\n');

  // **********************************************
  // 🎨 VAPOR CONFIGURATION
  // "Even more colorless" = Almost zero saturation.
  // Result: "Warm Whites", "Cool Whites", "Mist".
  // **********************************************
  
  // Saturation: 0.03 - 0.10
  // barely enough to distinguish "warm" from "cool", but looks white at a glance.
  const double minSat = 0.03;
  const double maxSat = 0.10;

  // Lightness: 0.93 - 0.99
  // Pure, clean brightness.
  const double minLight = 0.93;
  const double maxLight = 0.99;

  // 1. Locate directories
  final projectRoot = Directory.current;
  final habitsDir = Directory(p.join(projectRoot.path, 'assets', 'habits'));
  final outputDir = Directory(p.join(projectRoot.path, 'lib', 'data'));
  
  if (!habitsDir.existsSync()) {
    print('❌ Error: assets/habits/ folder not found.');
    print('Make sure you run this from the project root.');
    exit(1);
  }

  // Ensure output directory exists
  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }

  // 2. Start building the file content
  final buffer = StringBuffer();
  buffer.writeln("// AUTO-GENERATED FILE. DO NOT EDIT.");
  buffer.writeln("// Run 'dart run lib/tools/gen_colors.dart' to update.");
  buffer.writeln("import 'dart:ui';");
  buffer.writeln("");
  buffer.writeln("final Map<String, dynamic> themeData = {");

  // 3. Find and sort theme folders
  final folders = habitsDir.listSync()
      .whereType<Directory>()
      .toList()
    ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

  for (var folder in folders) {
    final themeName = p.basename(folder.path);
    final displayName = themeName[0].toUpperCase() + themeName.substring(1);
    
    print('📂 Processing Theme: $displayName');

    buffer.writeln("  '$themeName': {");
    buffer.writeln("    'name': '$displayName',");
    buffer.writeln("    'colors': [");

    // 4. Find and sort images
    final images = folder.listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.jpg'))
        .toList();

    images.sort((a, b) {
      final idA = int.tryParse(p.basenameWithoutExtension(a.path)) ?? 99;
      final idB = int.tryParse(p.basenameWithoutExtension(b.path)) ?? 99;
      return idA.compareTo(idB);
    });

    // 5. Extract Colors
    for (var file in images) {
      try {
        final bytes = file.readAsBytesSync();
        final image = img.decodeImage(bytes);

        if (image == null) {
          buffer.writeln("      const Color(0xFFF5F5F5), // Decode Error");
          continue;
        }

        // Resize for speed (analysis doesn't need 4k resolution)
        final thumb = img.copyResize(image, width: 100);
        
        // Pass the pastel ranges to the NEW dominant color extractor
        final colorInt = _getDominantColor(thumb, minSat, maxSat, minLight, maxLight);
        
        final r = (colorInt >> 16) & 0xFF;
        final g = (colorInt >> 8) & 0xFF;
        final b = (colorInt >> 0) & 0xFF;
        final hex = '0xFF${_toHex(r)}${_toHex(g)}${_toHex(b)}';

        buffer.writeln("      const Color($hex), // ${p.basename(file.path)}");

      } catch (e) {
        print('   ⚠️ Error: ${file.path}');
        buffer.writeln("      const Color(0xFFF5F5F5), // Error");
      }
    }

    buffer.writeln("    ],");
    buffer.writeln("  },");
  }

  buffer.writeln("};");

  // 6. Write to file
  final outputFile = File(p.join(outputDir.path, 'theme_colors.dart'));
  outputFile.writeAsStringSync(buffer.toString());

  print('\n✅ SUCCESS!');
  print('Generated file: ${outputFile.path}');
}

// Function to find the DOMINANT (most frequent) hue, then force it to pastel
int _getDominantColor(img.Image image, double minS, double maxS, double minL, double maxL) {
  final Map<int, int> colorCounts = {};
  
  // 1. Build a Histogram
  for (var pixel in image) {
    final r = pixel.r.toInt();
    final g = pixel.g.toInt();
    final b = pixel.b.toInt();
    
    // Skip near-black and near-white to avoid background interference
    // We want the tone of the *object*, not the white background or dark shadows
    final brightness = (r + g + b) / 3;
    if (brightness < 25 || brightness > 245) continue;
    
    // Quantize: Group similar colors.
    // Rounding to nearest 20 reduces noise (e.g., 121 and 124 become the same color).
    // This makes sure a large flat area counts as one "vote" for that color.
    const binSize = 20;
    final qR = (r ~/ binSize) * binSize;
    final qG = (g ~/ binSize) * binSize;
    final qB = (b ~/ binSize) * binSize;
    
    // Create a key for the map
    final colorKey = (0xFF << 24) | (qR << 16) | (qG << 8) | qB;
    
    colorCounts[colorKey] = (colorCounts[colorKey] ?? 0) + 1;
  }
  
  // 2. Fallback if image is pure B&W or empty
  if (colorCounts.isEmpty) {
    return _forcePastel(0xFF808080, minS, maxS, minL, maxL); 
  }
  
  // 3. Find the color with the highest count
  int dominantColor = 0xFFCCCCCC;
  int maxCount = 0;
  
  colorCounts.forEach((color, count) {
    if (count > maxCount) {
      maxCount = count;
      dominantColor = color;
    }
  });
  
  // 4. Apply the Pastel Enforcer to the winner
  return _forcePastel(dominantColor, minS, maxS, minL, maxL); 
}

// The Pastel Enforcer: Takes a dirty color, keeps the Hue, forces clean S/V
int _forcePastel(int color, double minS, double maxS, double minL, double maxL) {
  var r = (color >> 16) & 0xFF;
  var g = (color >> 8) & 0xFF;
  var b = (color >> 0) & 0xFF;
  
  // 1. Get HSV
  final maxRGB = max(r, max(g, b)) / 255.0;
  final minRGB = min(r, min(g, b)) / 255.0;
  final delta = maxRGB - minRGB;
  
  double h = 0;
  if (delta == 0) {
    h = 0; 
  } else if (maxRGB == r / 255.0) {
    h = 60 * (((g / 255.0 - b / 255.0) / delta) % 6);
  } else if (maxRGB == g / 255.0) {
    h = 60 * (((b / 255.0 - r / 255.0) / delta) + 2);
  } else {
    h = 60 * (((r / 255.0 - g / 255.0) / delta) + 4);
  }
  
  // 2. Force Pastel Values
  final randomizer = (h / 360.0); 
  
  // Force low saturation (Less colorish)
  final s = minS + (randomizer * (maxS - minS)); 
  
  // Force high lightness (Pastellish/Bright)
  final v = maxL - ((1.0 - randomizer) * (maxL - minL)); 
  
  // 3. Back to RGB
  final c = v * s;
  final x = c * (1 - ((h / 60) % 2 - 1).abs());
  final m = v - c;
  
  double rPrime = 0, gPrime = 0, bPrime = 0;
  
  if (h < 60) {
    rPrime = c; gPrime = x; bPrime = 0;
  } else if (h < 120) {
    rPrime = x; gPrime = c; bPrime = 0;
  } else if (h < 180) {
    rPrime = 0; gPrime = c; bPrime = x;
  } else if (h < 240) {
    rPrime = 0; gPrime = x; bPrime = c;
  } else if (h < 300) {
    rPrime = x; gPrime = 0; bPrime = c;
  } else {
    rPrime = c; gPrime = 0; bPrime = x;
  }
  
  r = ((rPrime + m) * 255).round().clamp(0, 255);
  g = ((gPrime + m) * 255).round().clamp(0, 255);
  b = ((bPrime + m) * 255).round().clamp(0, 255);
  
  return (0xFF << 24) | (r << 16) | (g << 8) | b;
}

String _toHex(int value) => value.toRadixString(16).toUpperCase().padLeft(2, '0');