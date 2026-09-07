// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'knowledge_notes_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$knowledgeNotesNotifierHash() =>
    r'1f0ce7cf47b9855f2865109a27318fa59dadc23b';

/// Loads the current target language's knowledge notes, seeding the starter
/// library on first access, and exposes optimistic CRUD mutations.
///
/// Copied from [KnowledgeNotesNotifier].
@ProviderFor(KnowledgeNotesNotifier)
final knowledgeNotesNotifierProvider = AutoDisposeAsyncNotifierProvider<
    KnowledgeNotesNotifier, List<KnowledgeNote>>.internal(
  KnowledgeNotesNotifier.new,
  name: r'knowledgeNotesNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$knowledgeNotesNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$KnowledgeNotesNotifier
    = AutoDisposeAsyncNotifier<List<KnowledgeNote>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
