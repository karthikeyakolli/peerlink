import 'dart:io';
import 'package:flutter/foundation.dart';

class SearchResultItem {
  final String filePath;
  final String fileName;
  final String snippet;
  final int score;

  const SearchResultItem({
    required this.filePath,
    required this.fileName,
    required this.snippet,
    required this.score,
  });
}

class OfflineFullTextSearchService extends ChangeNotifier {
  OfflineFullTextSearchService._();
  static final OfflineFullTextSearchService instance = OfflineFullTextSearchService._();

  final Map<String, Set<String>> _invertedIndex = {};
  final Map<String, String> _documents = {};

  int get indexedDocumentCount => _documents.length;

  void clearIndex() {
    _invertedIndex.clear();
    _documents.clear();
    notifyListeners();
  }

  void indexFile(String filePath, String text) {
    _documents[filePath] = text;
    final terms = _tokenize(text);

    for (final term in terms) {
      _invertedIndex.putIfAbsent(term, () => {}).add(filePath);
    }
    notifyListeners();
  }

  List<SearchResultItem> search(String query) {
    final queryTerms = _tokenize(query);
    if (queryTerms.isEmpty) return const [];

    final scores = <String, int>{};

    for (final term in queryTerms) {
      final matchingPaths = _invertedIndex[term] ?? const <String>{};
      for (final path in matchingPaths) {
        scores[path] = (scores[path] ?? 0) + 1;
      }
    }

    if (scores.isEmpty) return const [];

    final sorted = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final results = <SearchResultItem>[];

    for (final entry in sorted) {
      final path = entry.key;
      final fullText = _documents[path] ?? '';
      final snippet = _extractSnippet(fullText, queryTerms.first);
      final fileName = File(path).uri.pathSegments.last;

      results.add(SearchResultItem(
        filePath: path,
        fileName: fileName,
        snippet: snippet,
        score: entry.value,
      ));
    }

    return results;
  }

  Set<String> _tokenize(String text) {
    final clean = text.toLowerCase();
    final words = clean.split(RegExp(r'[^a-z0-9_]+'));
    return words.where((w) => w.length > 2).toSet();
  }

  String _extractSnippet(String text, String highlightWord) {
    final lower = text.toLowerCase();
    final idx = lower.indexOf(highlightWord.toLowerCase());
    if (idx == -1) {
      return text.length > 120 ? '${text.substring(0, 120)}...' : text;
    }

    final start = (idx - 40).clamp(0, text.length);
    final end = (idx + highlightWord.length + 60).clamp(0, text.length);
    var snippet = text.substring(start, end).replaceAll('\n', ' ').trim();

    if (start > 0) snippet = '...$snippet';
    if (end < text.length) snippet = '$snippet...';
    return snippet;
  }
}
