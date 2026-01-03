// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$appSettingsRepositoryHash() =>
    r'627bc2c4d1792dc036d4754bba5f553400c37285';

/// See also [appSettingsRepository].
@ProviderFor(appSettingsRepository)
final appSettingsRepositoryProvider = Provider<AppSettingsRepository>.internal(
  appSettingsRepository,
  name: r'appSettingsRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$appSettingsRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef AppSettingsRepositoryRef = ProviderRef<AppSettingsRepository>;
String _$appSettingsHash() => r'64a42bb71e28dbee450b3cc5b7d2e4249d14dd61';

/// See also [appSettings].
@ProviderFor(appSettings)
final appSettingsProvider = AutoDisposeStreamProvider<AppSetting>.internal(
  appSettings,
  name: r'appSettingsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$appSettingsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef AppSettingsRef = AutoDisposeStreamProviderRef<AppSetting>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
