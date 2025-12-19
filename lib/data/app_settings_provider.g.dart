// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$appSettingsRepositoryHash() =>
    r'462751109e3a1597bd2df7ade23960f5ba1a604a';

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
String _$appSettingsHash() => r'0856dbb059e82de249abdcd45a5e547b09af40ae';

/// See also [appSettings].
@ProviderFor(appSettings)
final appSettingsProvider = AutoDisposeStreamProvider<AppSettings>.internal(
  appSettings,
  name: r'appSettingsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$appSettingsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef AppSettingsRef = AutoDisposeStreamProviderRef<AppSettings>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
