import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../dictionary/domain/entities/language.dart';
import '../domain/entities/knowledge_note.dart';

/// Loads the app-bundled starter Knowledge Notes for a target language from
/// `assets/knowledge/starter_<code>.json`. v1 ships English only; any other
/// language (or a missing/corrupt asset) yields `[]`.
class KnowledgeStarterLibrary {
  KnowledgeStarterLibrary({Future<String> Function(String assetKey)? loadAsset})
      : _load = loadAsset ?? rootBundle.loadString;

  final Future<String> Function(String assetKey) _load;

  Future<List<KnowledgeNote>> notesFor(Language language) async {
    try {
      final raw = await _load('assets/knowledge/starter_${language.code}.json');
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return list.map(KnowledgeNote.fromJson).toList();
    } catch (_) {
      return const [];
    }
  }
}
