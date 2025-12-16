import 'dart:math'; 
import 'package:fiveyear/data/habit_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/habit_schema.dart';
import '../../data/theme_colors.dart'; 

class AddHabitScreen extends ConsumerStatefulWidget {
  const AddHabitScreen({super.key});

  @override
  ConsumerState<AddHabitScreen> createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends ConsumerState<AddHabitScreen> {
  String name = '';
  String selectedTheme = 'scholar';
  Color backendColor = Colors.green; 
  
  // Default Icon
  IconData selectedIcon = Icons.emoji_events;

  // --- ICON LIBRARY ---
final List<IconData> _availableIcons = [
    // 1. GENERAL / PRODUCTIVITY
    Icons.emoji_events, Icons.star, Icons.flag, Icons.check_circle,
    Icons.timeline, Icons.lightbulb, Icons.bolt, Icons.local_fire_department,
    Icons.access_alarm, Icons.timer, Icons.schedule, Icons.today,
    Icons.done_all, Icons.priority_high, Icons.list, Icons.category,

    // 2. SPORTS & FITNESS
    Icons.directions_run, Icons.fitness_center, Icons.pool, Icons.directions_bike,
    Icons.hiking, Icons.kayaking, Icons.rowing, Icons.downhill_skiing,
    Icons.snowboarding, Icons.skateboarding, Icons.surfing, Icons.kitesurfing,
    Icons.sports_soccer, Icons.sports_tennis, Icons.sports_basketball, Icons.sports_football,
    Icons.sports_baseball, Icons.sports_volleyball, Icons.sports_golf, Icons.sports_cricket,
    Icons.sports_mma, Icons.sports_kabaddi, Icons.sports_hockey, Icons.sports_rugby,
    Icons.sports_handball, Icons.sports_motorsports, Icons.roller_skating, Icons.ice_skating,
    
    // 3. HEALTH & WELLNESS
    Icons.self_improvement, Icons.spa, Icons.water_drop, Icons.bed,
    Icons.monitor_heart, Icons.local_dining, Icons.no_drinks, Icons.smoke_free,
    Icons.medication, Icons.healing, Icons.monitor_weight, Icons.hotel,
    Icons.bathtub, Icons.accessibility_new, Icons.mood, Icons.sentiment_very_satisfied,
    
    // 4. LEARNING & WORK
    Icons.book, Icons.school, Icons.menu_book, Icons.edit,
    Icons.computer, Icons.code, Icons.work, Icons.business_center,
    Icons.assignment, Icons.calendar_today, Icons.access_time, Icons.language,
    Icons.science, Icons.psychology, Icons.calculate, Icons.architecture,
    Icons.biotech, Icons.history_edu, Icons.design_services, Icons.translate,

    // 5. CREATIVITY & ARTS
    Icons.palette, Icons.brush, Icons.camera_alt, Icons.music_note,
    Icons.headphones, Icons.mic, Icons.movie, Icons.theater_comedy,
    Icons.piano, Icons.photo_camera, Icons.draw, Icons.create,
    Icons.video_camera_back, Icons.lyrics, Icons.speaker, Icons.album,

    // 6. FINANCE
    Icons.attach_money, Icons.savings, Icons.account_balance_wallet, Icons.trending_up,
    Icons.euro, Icons.currency_pound, Icons.currency_yen, Icons.pie_chart,
    Icons.show_chart, Icons.bar_chart, Icons.credit_card, Icons.receipt_long,
    
    // 7. LIFESTYLE, HOME & CHORES
    Icons.home, Icons.cleaning_services, Icons.local_laundry_service, Icons.bedtime,
    Icons.shopping_cart, Icons.restaurant, Icons.local_cafe, Icons.kitchen,
    Icons.chair, Icons.weekend, Icons.family_restroom, Icons.child_care,
    Icons.pets, Icons.cruelty_free, Icons.volunteer_activism, Icons.church,
    Icons.mosque, Icons.synagogue, Icons.temple_buddhist, Icons.temple_hindu,
    Icons.iron, Icons.grass, Icons.construction, Icons.handyman,

    // 8. NATURE & TRAVEL
    Icons.forest, Icons.park, Icons.terrain, Icons.wb_sunny,
    Icons.nightlight_round, Icons.flight, Icons.directions_car, Icons.train,
    Icons.directions_boat, Icons.map, Icons.explore, Icons.public,
    Icons.compost, Icons.recycling, Icons.nature_people,
    Icons.sailing, Icons.two_wheeler, Icons.directions_bus, Icons.commute,

    // 9. TECH & GAMING
    Icons.smartphone, Icons.gamepad, Icons.sports_esports, Icons.laptop,
    Icons.memory, Icons.security, Icons.wifi, Icons.battery_charging_full,
    Icons.keyboard, Icons.mouse, Icons.developer_mode, Icons.router,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateSelectedColor();
    });
  }

  Color _getColorForTheme(String themeKey) {
    if (!themeData.containsKey(themeKey)) return Colors.grey;
    final List<Color> colors = themeData[themeKey]['colors'];
    if (colors.isEmpty) return Colors.black;
    final int currentYear = DateTime.now().year;
    return colors[currentYear % colors.length];
  }

  Color _getReadableColor(Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final HSLColor hsl = HSLColor.fromColor(color);
    if (isDark) {
      return hsl.withLightness(max(hsl.lightness, 0.75)).toColor();
    } else {
      return hsl.withLightness(min(hsl.lightness, 0.4)).toColor();
    }
  }

  void _updateSelectedColor() {
    setState(() {
      backendColor = _getColorForTheme(selectedTheme);
    });
  }

  void _createHabit() {
    if (name.isEmpty) return;
    final newHabit = Habit()
      ..name = name
      ..colorValue = backendColor.value 
      ..theme = selectedTheme
      ..customImagePath = null
      ..iconCodePoint = selectedIcon.codePoint 
      ..completedDays = [];

    ref.read(habitRepositoryProvider).addHabit(newHabit);
    Navigator.pop(context);
  }

  void _showIconPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              const SizedBox(height: 16),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              Text(
                "Select Icon",
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black
                )
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _availableIcons.length,
                  itemBuilder: (context, index) {
                    final icon = _availableIcons[index];
                    final isSelected = (icon == selectedIcon);
                    final iconColor = _getReadableColor(backendColor);

                    return GestureDetector(
                      onTap: () {
                        setState(() => selectedIcon = icon);
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected 
                            ? iconColor.withOpacity(0.2) 
                            : (isDark ? Colors.grey[800] : Colors.grey[100]),
                          shape: BoxShape.circle,
                          border: isSelected 
                            ? Border.all(color: iconColor, width: 2) 
                            : null,
                        ),
                        child: Icon(
                          icon,
                          size: 28,
                          color: isSelected ? iconColor : (isDark ? Colors.grey[400] : Colors.grey[600]),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final surfaceColor = Theme.of(context).colorScheme.surface;
    
    final Color activeColor = _getReadableColor(backendColor);
    final Color createBtnColor = name.isNotEmpty 
        ? activeColor 
        : (isDark ? Colors.grey[700]! : Colors.grey[300]!);

    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppBar(
        title: Text("New Habit", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: name.isNotEmpty ? _createHabit : null, 
            child: Text(
              "Create", 
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: createBtnColor)
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
              // --- 1. NAME INPUT ---
              TextField(
                autofocus: false,
                style: TextStyle(color: textColor),
                cursorColor: activeColor,
                decoration: InputDecoration(
                  labelText: "Name",
                  labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  filled: true, 
                  fillColor: isDark ? Colors.grey[900] : const Color(0xFFF8FAFC), 
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)), 
                    borderSide: BorderSide.none
                  )
                ), 
                onChanged: (val) {
                   setState(() => name = val);
                   _updateSelectedColor(); 
                }
              ),
              
              const SizedBox(height: 32),

              // --- 2. ICON SELECTOR (NO TITLE) ---
              GestureDetector(
                onTap: _showIconPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[900] : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: activeColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(selectedIcon, color: activeColor),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        "Select Icon",
                        style: TextStyle(color: textColor, fontSize: 16),
                      ),
                      const Spacer(),
                      Icon(Icons.chevron_right, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),
              
              // --- 3. THEME SELECTION (FULL WIDTH CLOUD) ---
              Text(
                "Select Theme", 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)
              ),
              const SizedBox(height: 12),

              // Wrap automatically takes full width of the parent (Column), 
              // which adheres to the padding of SingleChildScrollView (24).
              Wrap(
                spacing: 12, 
                runSpacing: 12, 
                alignment: WrapAlignment.start, // Left aligned to fill width naturally
                children: themeData.entries.map((e) {
                  final key = e.key;
                  final data = e.value;
                  final isSelected = (selectedTheme == key);
                  final rawColor = _getColorForTheme(key);
                  final contrastColor = _getReadableColor(rawColor);
                  final inactiveBg = isDark ? Colors.grey[900]! : const Color(0xFFF4F4F5);
                  final inactiveText = isDark ? Colors.grey[400] : Colors.black87;

                  return GestureDetector(
                    onTap: () {
                      setState(() { 
                        selectedTheme = key; 
                        _updateSelectedColor(); 
                      });
                    }, 
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), 
                      decoration: BoxDecoration(
                        color: isSelected ? rawColor.withOpacity(isDark ? 0.25 : 0.15) : inactiveBg, 
                        border: Border.all(
                          color: isSelected ? contrastColor : Colors.transparent, 
                          width: 2
                        ), 
                        borderRadius: BorderRadius.circular(12)
                      ), 
                      child: Text(
                        data['name'], 
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isSelected ? contrastColor : inactiveText 
                        )
                      )
                    )
                  );
                }).toList()
              ),
              
              // Extra padding at bottom so scrolling feels natural
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}