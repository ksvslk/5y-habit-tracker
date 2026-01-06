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
  TimeOfDay _selectedTime = const TimeOfDay(hour: 20, minute: 0);
  bool _enableNotifications = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Daily Check-in'),
      backgroundColor: colorScheme.surfaceContainerHigh, // Solid dialog
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('When should we remind you?'),
          const SizedBox(height: 20),
          InkWell(
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _selectedTime,
                initialEntryMode: TimePickerEntryMode.input,
              );
              if (picked != null) {
                setState(() => _selectedTime = picked);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.primary),
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
          SwitchListTile(
            title: const Text('Get Notified'),
            value: _enableNotifications,
            onChanged: (bool value) async {
              final notificationService =
                  ref.read(notificationServiceProvider);
              bool finalState = value;

              if (value) {
                final standardGranted =
                    await notificationService.requestNotificationPermission();

                if (standardGranted) {
                  await notificationService.requestExactAlarmPermission();
                  final exactGranted =
                      await notificationService.hasExactAlarmPermission();
                  finalState = standardGranted && exactGranted;

                  if (!exactGranted && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'For best results, allow "Alarms & reminders".'),
                        duration: Duration(seconds: 4),
                      ),
                    );
                  }
                } else {
                  finalState = false;
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Notification permission was denied.'),
                      ),
                    );
                  }
                }
              }
              // Update the local UI state
              setState(() {
                _enableNotifications = finalState;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: _saveAndClose, child: const Text('Done')),
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

    await ref
        .read(appSettingsRepositoryProvider)
        .finalizeOnboarding(_enableNotifications, reminderTime);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}
