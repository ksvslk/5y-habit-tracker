import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

void main() {
  print('\n🔵 Starting Auto-Generator (Overall Atmospheric Tone)...\n');

  // **********************************************
  // 🎨 VAPOR CONFIGURATION
  // **********************************************
  // We keep the saturation low to ensure the result is a "tint", not a solid color.
  const double targetSatMin = 0.04;
  const double targetSatMax = 0.10;

  // High lightness ensures it fits your "white/clean" aesthetic.
  const double targetLightMin = 0.92;
  const double targetLightMax = 0.98;

  final projectRoot = Directory.current;
  final habitsDir = Directory(p.join(projectRoot.path, 'assets', 'habits'));
  final outputDir = Directory(p.join(projectRoot.path, 'lib', 'data'));

  if (!habitsDir.existsSync()) {
    print('❌ Error: assets/habits/ folder not found.');
    exit(1);
  }

  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }

  final buffer = StringBuffer();
  buffer.writeln("// AUTO-GENERATED FILE. DO NOT EDIT.");
  buffer.writeln("import 'dart:ui';");
  buffer.writeln("");
  buffer.writeln("final Map<String, dynamic> themeData = {");

  final folders = habitsDir.listSync().whereType<Directory>().toList()
    ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

  for (var folder in folders) {
    final themeName = p.basename(folder.path);
    final displayName = themeName[0].toUpperCase() + themeName.substring(1);

    print('📂 Processing Theme: $displayName');

    buffer.writeln("  '$themeName': {");
    buffer.writeln("    'name': '$displayName',");
    buffer.writeln("    'colors': [");

    final images = folder
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.jpg'))
        .toList();

    images.sort((a, b) {
      final idA = int.tryParse(p.basenameWithoutExtension(a.path)) ?? 99;
      final idB = int.tryParse(p.basenameWithoutExtension(b.path)) ?? 99;
      return idA.compareTo(idB);
    });

    for (var file in images) {
      try {
        final bytes = file.readAsBytesSync();
        final image = img.decodeImage(bytes);

        if (image == null) {
          buffer.writeln("      const Color(0xFFF5F5F5), // Decode Error");
          continue;
        }

        // Resize to a very small thumbnail (50px).
        // This naturally blurs details and helps calculate the "average" tone
        // without getting distracted by tiny sharp details.
        final thumb = img.copyResize(image, width: 50);

        final colorInt = _getAtmosphereColor(
          thumb,
          targetSatMin,
          targetSatMax,
          targetLightMin,
          targetLightMax,
        );

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

  final outputFile = File(p.join(outputDir.path, 'theme_colors.dart'));
  outputFile.writeAsStringSync(buffer.toString());

  print('\n✅ SUCCESS! File generated at: ${outputFile.path}');
}

// ---------------------------------------------------------------------------
// 🌫️ ATMOSPHERIC AVERAGE EXTRACTOR
// ---------------------------------------------------------------------------

int _getAtmosphereColor(
  img.Image image,
  double minS,
  double maxS,
  double minL,
  double maxL,
) {
  int rSum = 0;
  int gSum = 0;
  int bSum = 0;
  int count = 0;

  for (var pixel in image) {
    final r = pixel.r.toInt();
    final g = pixel.g.toInt();
    final b = pixel.b.toInt();

    // Only skip absolute pure black/white borders if they exist.
    // Otherwise, include EVERYTHING. The gray wall, the white table,
    // the blue sky—they all contribute to the "Tone".
    final brightness = (r + g + b) / 3;
    if (brightness < 10 || brightness > 250) continue;

    rSum += r;
    gSum += g;
    bSum += b;
    count++;
  }

  // Fallback
  if (count == 0) return 0xFFF5F5F5;

  // Calculate the Average (Mean) Color
  // This blends the accent and the background into one single "Mood" color.
  final avgR = rSum ~/ count;
  final avgG = gSum ~/ count;
  final avgB = bSum ~/ count;

  final averageColor = (0xFF << 24) | (avgR << 16) | (avgG << 8) | avgB;

  // Apply the Pastel Enforcer to ensure it fits the UI lightness requirements
  return _forcePastel(averageColor, minS, maxS, minL, maxL);
}

int _forcePastel(
  int color,
  double minS,
  double maxS,
  double minL,
  double maxL,
) {
  var r = (color >> 16) & 0xFF;
  var g = (color >> 8) & 0xFF;
  var b = (color >> 0) & 0xFF;

  // 1. Convert to HSV to extract the Hue
  final maxRGB = max(r, max(g, b)) / 255.0;
  final minRGB = min(r, min(g, b)) / 255.0;
  final delta = maxRGB - minRGB;

  double h = 0;
  if (delta == 0) {
    // If the image is perfectly Grayscale (no hue),
    // we can't extract a tone. Default to a warm "Paper White" hue (40°).
    h = 40;
  } else if (maxRGB == r / 255.0) {
    h = 60 * (((g / 255.0 - b / 255.0) / delta) % 6);
  } else if (maxRGB == g / 255.0) {
    h = 60 * (((b / 255.0 - r / 255.0) / delta) + 2);
  } else {
    h = 60 * (((r / 255.0 - g / 255.0) / delta) + 4);
  }

  if (h < 0) h += 360;

  // 2. Force the Vapor Variables
  // We keep the extracted Hue, but we OVERWRITE Saturation and Value.

  // Use a fixed "Vapor" saturation (very low)
  final s = minS + 0.5 * (maxS - minS);

  // Use a fixed "Vapor" lightness (very high)
  final v = maxL - 0.5 * (maxL - minL);

  // 3. Convert back to RGB
  final c = v * s;
  final x = c * (1 - ((h / 60) % 2 - 1).abs());
  final m = v - c;

  double rPrime = 0, gPrime = 0, bPrime = 0;

  if (h < 60) {
    rPrime = c;
    gPrime = x;
    bPrime = 0;
  } else if (h < 120) {
    rPrime = x;
    gPrime = c;
    bPrime = 0;
  } else if (h < 180) {
    rPrime = 0;
    gPrime = c;
    bPrime = x;
  } else if (h < 240) {
    rPrime = 0;
    gPrime = x;
    bPrime = c;
  } else if (h < 300) {
    rPrime = x;
    gPrime = 0;
    bPrime = c;
  } else {
    rPrime = c;
    gPrime = 0;
    bPrime = x;
  }

  r = ((rPrime + m) * 255).round().clamp(0, 255);
  g = ((gPrime + m) * 255).round().clamp(0, 255);
  b = ((bPrime + m) * 255).round().clamp(0, 255);

  return (0xFF << 24) | (r << 16) | (g << 8) | b;
}

String _toHex(int value) =>
    value.toRadixString(16).toUpperCase().padLeft(2, '0');
