import 'dart:io';
import 'package:fiveyear/data/habit_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:palette_generator/palette_generator.dart';
import '../../data/habit_schema.dart'; // Import your Isar schema

class AddHabitDialog extends ConsumerStatefulWidget {
  const AddHabitDialog({super.key});

  @override
  ConsumerState<AddHabitDialog> createState() => _AddHabitDialogState();
}

class _AddHabitDialogState extends ConsumerState<AddHabitDialog> {
  String name = '';
  Color selectedColor = Colors.green;
  String selectedTheme = 'nature';
  String? customPath;
  bool isCustom = false;
  bool isScanning = false;

  final ImagePicker _picker = ImagePicker();
  
  final List<Color> colors = [
    Colors.green, Colors.blue, Colors.purple, Colors.orange, Colors.pink, Colors.black87
  ];
  
  final Map<String, String> themes = {
    'nature': 'Nature', 'sport': 'Sport', 'reading': 'Reading'
  };

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      setState(() {
        customPath = image.path;
        isScanning = true;
        isCustom = true;
      });
      
      // Optional: Extract color from image
      try {
        final PaletteGenerator generator = await PaletteGenerator.fromImageProvider(
          ResizeImage(FileImage(File(image.path)), width: 300),
          size: const Size(200, 200),
        );
        if (generator.dominantColor != null) {
          setState(() {
            selectedColor = generator.dominantColor!.color;
          });
        }
      } catch (e) {
        debugPrint("Error scanning image: $e");
      } finally {
        setState(() => isScanning = false);
      }
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt), 
              title: const Text('Scan with Camera'), 
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); }
            ),
            ListTile(
              leading: const Icon(Icons.photo_library), 
              title: const Text('Pick from Gallery'), 
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); }
            ),
          ],
        ),
      ),
    );
  }

  void _createHabit() {
    if (name.isEmpty) return;

    // Create the Isar object
    final newHabit = Habit()
      ..name = name
      ..colorValue = selectedColor.value // Store Color as int
      ..theme = selectedTheme
      ..customImagePath = customPath
      ..completedDays = []; // Initialize empty list

    // Use Riverpod to access the Repository
    ref.read(habitRepositoryProvider).addHabit(newHabit);

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("New Habit", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              
              // Name Input
              TextField(
                decoration: const InputDecoration(
                  labelText: "Name", 
                  filled: true, 
                  fillColor: Color(0xFFF1F5F9), 
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide.none)
                ), 
                onChanged: (val) => setState(() => name = val)
              ),
              const SizedBox(height: 20),
              
              // Color Picker
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                children: [
                  const Text("Color", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)), 
                  if (isScanning) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                ]
              ),
              const SizedBox(height: 8),
              Row(
                children: colors.map((c) => GestureDetector(
                  onTap: () => setState(() => selectedColor = c), 
                  child: Container(
                    margin: const EdgeInsets.only(right: 8), 
                    width: 32, height: 32, 
                    decoration: BoxDecoration(
                      color: c, 
                      shape: BoxShape.circle, 
                      border: selectedColor == c ? Border.all(color: Colors.black, width: 2) : null
                    )
                  )
                )).toList()
              ),
              const SizedBox(height: 20),
              
              // Theme Selector
              const Text("Theme", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, 
                runSpacing: 8, 
                children: themes.entries.map((e) => GestureDetector(
                  onTap: () => setState(() { selectedTheme = e.key; isCustom = false; customPath = null; }), 
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
                    decoration: BoxDecoration(
                      color: (!isCustom && selectedTheme == e.key) ? selectedColor.withOpacity(0.1) : Colors.grey[100], 
                      border: (!isCustom && selectedTheme == e.key) ? Border.all(color: selectedColor) : null, 
                      borderRadius: BorderRadius.circular(12)
                    ), 
                    child: Text(e.value, style: TextStyle(color: (!isCustom && selectedTheme == e.key) ? selectedColor : Colors.black87))
                  )
                )).toList()
              ),
              const SizedBox(height: 16),
              
              // Image Picker Button
              GestureDetector(
                onTap: _showImageSourceSheet, 
                child: Container(
                  width: double.infinity, 
                  padding: const EdgeInsets.all(16), 
                  decoration: BoxDecoration(
                    color: isCustom ? Colors.black.withOpacity(0.05) : Colors.transparent, 
                    border: Border.all(color: isCustom ? Colors.black : Colors.grey[300]!, style: isCustom ? BorderStyle.solid : BorderStyle.none), 
                    borderRadius: BorderRadius.circular(16)
                  ), 
                  child: Column(children: [
                    Icon(Icons.add_a_photo, color: isCustom ? Colors.black : Colors.grey), 
                    const SizedBox(height: 8), 
                    Text(customPath != null ? "Image Selected" : "Scan or Pick Image", style: TextStyle(fontWeight: FontWeight.bold, color: isCustom ? Colors.black : Colors.grey))
                  ])
                )
              ),
              const SizedBox(height: 24),
              
              // Create Button
              SizedBox(
                width: double.infinity, 
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black, 
                    foregroundColor: Colors.white, 
                    padding: const EdgeInsets.symmetric(vertical: 16), 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                  ), 
                  onPressed: name.isNotEmpty ? _createHabit : null, 
                  child: const Text("Create", style: TextStyle(fontWeight: FontWeight.bold))
                )
              )
            ],
          ),
        ),
      ),
    );
  }
}