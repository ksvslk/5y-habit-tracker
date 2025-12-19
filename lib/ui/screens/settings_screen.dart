import 'package:fiveyear/data/app_settings_provider.dart';
import 'package:fiveyear/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(appSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (settings) {
          return ListView(
            children: [
              ListTile(
                title: const Text(
                  'Daily Reminder',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
              SwitchListTile(
                title: const Text('Enable Notifications'),
                value: settings.isReminderEnabled,
                onChanged: (bool value) async {
                  // --- CHANGED LOGIC START ---
                  if (value) {
                    // 1. Ask Permission
                    final bool granted = await ref
                        .read(notificationServiceProvider)
                        .requestPermissions();

                    // 2. If denied, STOP here. Do not update settings.
                    if (!granted) {
                      // Optional: Show a snackbar telling them to go to Settings
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Permission denied. Please enable notifications in system settings.',
                            ),
                          ),
                        );
                      }
                      return;
                    }
                  }
                  // --- CHANGED LOGIC END ---

                  // 3. Only update if permission granted (or if turning OFF)
                  ref
                      .read(appSettingsRepositoryProvider)
                      .updateDailyReminder(value, settings.dailyReminderTime);
                },
              ),
              if (settings.isReminderEnabled)
                ListTile(
                  title: const Text('Reminder Time'),
                  subtitle: Text(_formatTime(settings.dailyReminderTime)),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final TimeOfDay? picked = await showTimePicker(
                      initialEntryMode: TimePickerEntryMode.inputOnly,
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(
                        settings.dailyReminderTime ?? DateTime.now(),
                      ),
                    );

                    if (picked != null) {
                      final now = DateTime.now();
                      final newTime = DateTime(
                        now.year,
                        now.month,
                        now.day,
                        picked.hour,
                        picked.minute,
                      );

                      ref
                          .read(appSettingsRepositoryProvider)
                          .updateDailyReminder(true, newTime);
                    }
                  },
                ),
              const Divider(),
              ListTile(
                title: const Text(
                  'Appearance',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return "Not set";
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return "$hour:$minute $period";
  }
}