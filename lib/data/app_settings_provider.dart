import 'package:fiveyear/data/app_settings_repository.dart';
import 'package:fiveyear/data/entities.dart';
import 'package:fiveyear/services/notification_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'database_provider.dart';

part 'app_settings_provider.g.dart';

// 1. Repository Provider
@Riverpod(keepAlive: true)
AppSettingsRepository appSettingsRepository(Ref ref) {
  final notificationService = ref.watch(notificationServiceProvider);
  final objectbox = ref.watch(objectboxProvider).requireValue; // This will wait
  return AppSettingsRepository(objectbox, notificationService);
}

// 2. Settings Stream
@Riverpod(keepAlive: true)
Stream<AppSetting> appSettings(Ref ref) {
  final repository = ref.watch(appSettingsRepositoryProvider);
  return repository.watchSettings();
}