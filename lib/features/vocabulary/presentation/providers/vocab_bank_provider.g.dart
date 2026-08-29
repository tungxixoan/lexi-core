// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vocab_bank_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$vocabBankHash() => r'c832a4ab981016f6e0209e85943bc5f9d58e5c7c';

/// Simple provider that returns the vocab list data synchronously.
/// Returns an empty list when loading or on error.
///
/// Copied from [vocabBank].
@ProviderFor(vocabBank)
final vocabBankProvider = AutoDisposeProvider<List<VocabRecord>>.internal(
  vocabBank,
  name: r'vocabBankProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$vocabBankHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef VocabBankRef = AutoDisposeProviderRef<List<VocabRecord>>;
String _$vocabBankNotifierHash() => r'6cd0a192880911fb62619834ba4b1009d81c1cbc';

/// See also [VocabBankNotifier].
@ProviderFor(VocabBankNotifier)
final vocabBankNotifierProvider = AutoDisposeAsyncNotifierProvider<
    VocabBankNotifier, List<VocabRecord>>.internal(
  VocabBankNotifier.new,
  name: r'vocabBankNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$vocabBankNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$VocabBankNotifier = AutoDisposeAsyncNotifier<List<VocabRecord>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
