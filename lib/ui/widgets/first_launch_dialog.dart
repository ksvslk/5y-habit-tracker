import 'package:fiveyear/data/app_settings_provider.dart';
import 'package:fiveyear/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FirstLaunchDialog extends ConsumerStatefulWidget {
  const FirstLaunchDialog({super.key});

  @override
  ConsumerState<FirstLaunchDialog> createState() => _FirstLaunchDialogState();
}

class _FirstLaunchDialogState extends ConsumerState<FirstLaunchDialog> {
  // Default to 8:00 PM
  TimeOfDay _selectedTime = const TimeOfDay(hour: 20, minute: 0);
  bool _enableNotifications = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Daily Check-in'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('When should we remind you?'),
          const SizedBox(height: 20),

          // 1. Time Picker Button
          InkWell(
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _selectedTime,
                initialEntryMode: TimePickerEntryMode.input, // Faster for users
              );
              if (picked != null) {
                setState(() => _selectedTime = picked);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).primaryColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _selectedTime.format(context),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 2. Notification Switch
          SwitchListTile(
            title: const Text('Get Notified'),
            value: _enableNotifications,
            onChanged: (val) async {
              setState(() => _enableNotifications = val);

              // 3. ASK PERMISSIONS IMMEDIATELY if toggled ON
              if (val) {
                await ref
                    .read(notificationServiceProvider)
                    .requestPermissions();
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _saveAndClose();
          },
          child: const Text('Start Journey'),
        ),
      ],
    );
  }

  Future<void> _saveAndClose() async {
    final now = DateTime.now();
    final reminderTime = DateTime(
      now.year,
      now.month,
      now.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    // USE THE NEW SINGLE METHOD
    await ref
        .read(appSettingsRepositoryProvider)
        .finalizeOnboarding(_enableNotifications, reminderTime);

    if (mounted) Navigator.of(context).pop();
  }
}
