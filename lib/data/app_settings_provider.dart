import 'package:fiveyear/data/app_settings_repository.dart';
import 'package:fiveyear/data/app_settings_schema.dart';
import 'package:fiveyear/data/database_provider.dart';
import 'package:fiveyear/services/notification_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_settings_provider.g.dart';

// 1. Repository Provider
@Riverpod(keepAlive: true)
AppSettingsRepository appSettingsRepository(AppSettingsRepositoryRef ref) {
  final notificationService = ref.watch(notificationServiceProvider);
  final dbFuture = ref.watch(isarDatabaseProvider.future);
  return AppSettingsRepository(dbFuture, notificationService);
}

// 2. Settings Stream (UI listens to this)
@riverpod
Stream<AppSettings> appSettings(AppSettingsRef ref) {
  final repository = ref.watch(appSettingsRepositoryProvider);
  
  // We stream the data so the UI updates instantly when you change time/theme
  return Stream.fromFuture(repository.getSettings()).asyncExpand((initialSettings) async* {
    yield initialSettings;
    
    // Watch for changes in the database
    final db = await repository.db;
    await for (final _ in db.appSettings.watchLazy()) {
      yield await repository.getSettings();
    }
  });
}