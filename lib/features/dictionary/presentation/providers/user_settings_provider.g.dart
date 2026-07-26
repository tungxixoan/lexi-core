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
String _$userSettingsNotifierHash() =>
    r'eeaa727e3b467492ff0fa681c0c39af8687adacd';

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
