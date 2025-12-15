import 'dart:io';
import 'package:fiveyear/data/habit_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:palette_generator/palette_generator.dart';
import '../../data/habit_schema.dart';

class AddHabitScreen extends ConsumerStatefulWidget {
  const AddHabitScreen({super.key});

  @override
  ConsumerState<AddHabitScreen> createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends ConsumerState<AddHabitScreen> {
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

    final newHabit = Habit()
      ..name = name
      ..colorValue = selectedColor.value
      ..theme = selectedTheme
      ..customImagePath = customPath
      ..completedDays = [];

    ref.read(habitRepositoryProvider).addHabit(newHabit);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("New Habit", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        // Close Button (Left)
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        // Create Button (Right)
        actions: [
          TextButton(
            onPressed: name.isNotEmpty ? _createHabit : null, 
            child: Text(
              "Create", 
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                fontSize: 16,
                color: name.isNotEmpty ? selectedColor : Colors.grey[400]
              )
            )
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name Input
              TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: "Name", 
                  filled: true, 
                  fillColor: Color(0xFFF8FAFC), 
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide.none)
                ), 
                onChanged: (val) => setState(() => name = val)
              ),
              const SizedBox(height: 32),
              
              // Color Picker
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                children: [
                  const Text("Color", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)), 
                  if (isScanning) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                ]
              ),
              const SizedBox(height: 12),
              Row(
                children: colors.map((c) => GestureDetector(
                  onTap: () => setState(() => selectedColor = c), 
                  child: Container(
                    margin: const EdgeInsets.only(right: 12), 
                    width: 40, height: 40, 
                    decoration: BoxDecoration(
                      color: c, 
                      shape: BoxShape.circle, 
                      border: selectedColor == c ? Border.all(color: Colors.black, width: 3) : null,
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]
                    )
                  )
                )).toList()
              ),
              const SizedBox(height: 32),
              
              // Theme Selector
              const Text("Theme", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12, 
                runSpacing: 12, 
                children: themes.entries.map((e) => GestureDetector(
                  onTap: () => setState(() { selectedTheme = e.key; isCustom = false; customPath = null; }), 
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), 
                    decoration: BoxDecoration(
                      color: (!isCustom && selectedTheme == e.key) ? selectedColor.withOpacity(0.1) : Colors.grey[100], 
                      border: (!isCustom && selectedTheme == e.key) ? Border.all(color: selectedColor, width: 2) : Border.all(color: Colors.transparent, width: 2), 
                      borderRadius: BorderRadius.circular(16)
                    ), 
                    child: Text(e.value, style: TextStyle(fontWeight: FontWeight.w600, color: (!isCustom && selectedTheme == e.key) ? selectedColor : Colors.black54))
                  )
                )).toList()
              ),
              const SizedBox(height: 24),
              
              // Image Picker Button
              GestureDetector(
                onTap: _showImageSourceSheet, 
                child: Container(
                  width: double.infinity, 
                  padding: const EdgeInsets.symmetric(vertical: 24), 
                  decoration: BoxDecoration(
                    color: isCustom ? Colors.black.withOpacity(0.03) : Colors.white, 
                    border: Border.all(color: isCustom ? Colors.black : Colors.grey[300]!, style: isCustom ? BorderStyle.solid : BorderStyle.none, width: 2), 
                    borderRadius: BorderRadius.circular(20)
                  ), 
                  child: Column(children: [
                    Icon(Icons.add_photo_alternate_outlined, size: 32, color: isCustom ? Colors.black : Colors.grey), 
                    const SizedBox(height: 8), 
                    Text(
                      customPath != null ? "Image Selected" : "Tap to pick a custom photo", 
                      style: TextStyle(fontWeight: FontWeight.bold, color: isCustom ? Colors.black : Colors.grey)
                    )
                  ])
                )
              ),
            ],
          ),
        ),
      ),
    );
  }
}