import 'package:fiveyear/data/app_settings_repository.dart';
import 'package:fiveyear/data/entities.dart';
import 'package:fiveyear/services/notification_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'database_provider.dart';

part 'app_settings_provider.g.dart';

// 1. Repository Provider
@Riverpod(keepAlive: true)
AppSettingsRepository appSettingsRepository(AppSettingsRepositoryRef ref) {
  final notificationService = ref.watch(notificationServiceProvider);
  final objectbox = ref.watch(objectboxProvider).value;

  if (objectbox == null) {
    throw Exception("ObjectBox store not available");
  }

  return AppSettingsRepository(objectbox, notificationService);
}

// 2. Settings Stream (UI listens to this)
@riverpod
Stream<AppSetting> appSettings(AppSettingsRef ref) {
  final repository = ref.watch(appSettingsRepositoryProvider);
  return repository.watchSettings();
}