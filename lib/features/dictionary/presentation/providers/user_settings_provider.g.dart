// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_settings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$sharedPreferencesHash() => r'72187c3700bbda9fefb11361fedc7ee11406ffc4';

/// See also [sharedPreferences].
@ProviderFor(sharedPreferences)
final sharedPreferencesProvider = Provider<SharedPreferences>.internal(
  sharedPreferences,
  name: r'sharedPreferencesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$sharedPreferencesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SharedPreferencesRef = ProviderRef<SharedPreferences>;
String _$apiKeyEncryptorHash() => r'7c16402d7f17eccdbaf67a93ca003fe2d704fd20';

/// See also [apiKeyEncryptor].
@ProviderFor(apiKeyEncryptor)
final apiKeyEncryptorProvider = Provider<ApiKeyEncryptor>.internal(
  apiKeyEncryptor,
  name: r'apiKeyEncryptorProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$apiKeyEncryptorHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ApiKeyEncryptorRef = ProviderRef<ApiKeyEncryptor>;
String _$userSettingsNotifierHash() =>
    r'e3321fdb16e41f7d49644cd36d2e1993eee57718';

/// See also [UserSettingsNotifier].
@ProviderFor(UserSettingsNotifier)
final userSettingsNotifierProvider =
    NotifierProvider<UserSettingsNotifier, UserSettingsState>.internal(
  UserSettingsNotifier.new,
  name: r'userSettingsNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$userSettingsNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$UserSettingsNotifier = Notifier<UserSettingsState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
