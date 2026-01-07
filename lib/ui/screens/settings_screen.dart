import 'dart:io';

import 'package:fiveyear/data/app_settings_provider.dart';
import 'package:fiveyear/data/entities.dart';
import 'package:fiveyear/data/subscription_service.dart';
import 'package:fiveyear/services/notification_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Silently sync status when the screen is first loaded.
    _syncNotificationStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _syncNotificationStatus();
    }
  }

  /// Silently checks permissions and updates the app state if it's out of sync.
  Future<void> _syncNotificationStatus() async {
    final settings = ref
        .read(appSettingsProvider)
        .when(
          data: (data) => data,
          loading: () => null,
          error: (_, __) => null,
        );

    if (settings == null || !settings.isReminderEnabled) {
      return;
    }

    final notificationService = ref.read(notificationServiceProvider);

    final standardGranted = await notificationService
        .hasNotificationPermission();
    final exactGranted = await notificationService.hasExactAlarmPermission();

    if (!standardGranted || !exactGranted) {
      ref
          .read(appSettingsRepositoryProvider)
          .updateDailyReminder(false, settings.dailyReminderTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(appSettingsProvider);
    final subscriptionAsync = ref.watch(subscriptionStatusProvider);
    final colorScheme = Theme.of(context).colorScheme;

    final bool isPro = subscriptionAsync.value ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => const Center(child: CircularProgressIndicator()),
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
                  final notificationService = ref.read(
                    notificationServiceProvider,
                  );
                  bool finalState = value;

                  if (value) {
                    final standardGranted = await notificationService
                        .requestNotificationPermission();

                    if (standardGranted) {
                      await notificationService.requestExactAlarmPermission();
                      final exactGranted = await notificationService
                          .hasExactAlarmPermission();
                      finalState = standardGranted && exactGranted;

                      if (!exactGranted && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'For best results, allow "Alarms & reminders".',
                            ),
                            duration: Duration(seconds: 4),
                          ),
                        );
                      }
                    } else {
                      final bool? result = await notificationService
                          .flutterLocalNotificationsPlugin
                          .resolvePlatformSpecificImplementation<
                            IOSFlutterLocalNotificationsPlugin
                          >()
                          ?.requestPermissions(
                            alert: true,
                            badge: true,
                            sound: true,
                          );

                      finalState = false;
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Notification permission was denied.',
                            ),
                          ),
                        );
                      }
                    }
                  }

                  ref
                      .read(appSettingsRepositoryProvider)
                      .updateDailyReminder(
                        finalState,
                        settings.dailyReminderTime,
                      );
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
                  : const SizedBox.shrink(),
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
