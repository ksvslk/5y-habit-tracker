import 'dart:io';

import 'package:fiveyear/data/app_settings_provider.dart';
import 'package:fiveyear/data/subscription_service.dart';
import 'package:fiveyear/services/notification_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(appSettingsProvider);
    final subscriptionAsync = ref.watch(subscriptionStatusProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // SIMPLER SOLUTION:
    // Just get the value. If it's loading or null, we assume 'false' (Not Pro)
    // so the UI renders immediately without a spinner.
    final bool isPro = subscriptionAsync.valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (settings) {
          return ListView(
            children: [
              ListTile(
                title: Text(
                  'Subscription',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ),

              // NO SPINNER. NO JANK.
              // It renders the "Choose Premium" button instantly.
              // If the user is actually Pro, it updates the text/icon automatically when data arrives.
              ListTile(
                leading: Icon(
                  isPro ? Icons.workspace_premium : Icons.lock,
                  color: isPro ? Colors.amber : colorScheme.onSurfaceVariant,
                ),
                title: Text(isPro ? 'Premium' : 'Choose Premium'),
                subtitle: Text(
                  isPro ? 'Thank you for your support!' : 'Unlock all features',
                ),
                trailing: isPro
                    ? Chip(
                        label: const Text('Active'),
                        backgroundColor: colorScheme.primaryContainer,
                        labelStyle: TextStyle(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: () {
                  if (isPro) {
                    null;
                  } else {
                    RevenueCatUI.presentPaywallIfNeeded("5Y Pro");
                  }
                },
              ),

              const Divider(),

              ListTile(
                title: Text(
                  'Daily Reminder',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              SwitchListTile(
                title: const Text('Enable Notifications'),
                value: settings.isReminderEnabled,
                onChanged: (bool value) async {
                  if (value) {
                    final bool granted = await ref
                        .read(notificationServiceProvider)
                        .requestPermissions();

                    if (!granted) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Permission denied. Please enable notifications in system settings.',
                              style: TextStyle(color: colorScheme.onError),
                            ),
                            backgroundColor: colorScheme.error,
                          ),
                        );
                      }
                      return;
                    }
                  }
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
                title: Text(
                  'About',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip),
                title: const Text('Privacy Policy'),
                onTap: () {
                  launchUrl(Uri.parse('https://indest.ee/5y-privacy-policy/'));
                },
              ),
              Platform.isIOS
                  ? ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('EULA'),
                      onTap: () {
                        launchUrl(Uri.parse('https://indest.ee/eula-for-5y/'));
                      },
                    )
                  : SizedBox.shrink(),
              ListTile(
                leading: const Icon(Icons.description),
                title: const Text('Licenses'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showLicensePage(
                    context: context,
                    applicationName: '5Y Habit Tracker',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.mail),
                title: const Text('Contact Me'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  launchUrl(
                    Uri.parse('mailto:indrek@indest.ee?subject=5Y&body=Hi!'),
                  );
                },
              ),
              const SizedBox(height: 20),
              const Divider(),

              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();

                  final version = snapshot.data!.version;
                  final buildNumber = snapshot.data!.buildNumber;
                  const commitHash = String.fromEnvironment(
                    'GIT_HASH',
                    defaultValue: 'Dev',
                  );

                  return ListTile(
                    title: Text(
                      'v$version ($buildNumber)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    subtitle: Text(
                      'Commit: $commitHash',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                        fontFamily: 'monospace',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
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
