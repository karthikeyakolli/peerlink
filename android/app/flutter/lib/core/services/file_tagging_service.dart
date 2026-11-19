import 'package:flutter/material.dart';

/// Represents a virtual tag badge with color and label.
class FileTag {
  final String label;
  final Color color;

  const FileTag({required this.label, required this.color});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileTag && runtimeType == other.runtimeType && label == other.label;

  @override
  int get hashCode => label.hashCode;
}

/// Service managing non-destructive virtual tags and color badges for vault files.
class FileTaggingService {
  FileTaggingService._() {
    _initDefaults();
  }
  static final FileTaggingService instance = FileTaggingService._();

  static const List<FileTag> defaultTags = [
    FileTag(label: 'Work', color: Color(0xFF2563EB)),
    FileTag(label: 'Personal', color: Color(0xFF9333EA)),
    FileTag(label: 'Taxes', color: Color(0xFFD97706)),
    FileTag(label: 'Receipts', color: Color(0xFF16A34A)),
    FileTag(label: 'Starred', color: Color(0xFFDC2626)),
  ];

  final Map<String, Set<FileTag>> _tagsByPath = {};

  void _initDefaults() {
    // Dynamic tag map: begins empty and records user-applied tags on real files
  }

  Set<FileTag> getTagsForFile(String path) {
    final fileName = path.split(RegExp(r'[/\\]')).last;
    return _tagsByPath[path] ?? _tagsByPath[fileName] ?? {};
  }

  void addTag(String path, FileTag tag) {
    final fileName = path.split(RegExp(r'[/\\]')).last;
    _tagsByPath.putIfAbsent(path, () => <FileTag>{}).add(tag);
    _tagsByPath.putIfAbsent(fileName, () => <FileTag>{}).add(tag);
  }

  void removeTag(String path, FileTag tag) {
    final fileName = path.split(RegExp(r'[/\\]')).last;
    _tagsByPath[path]?.remove(tag);
    _tagsByPath[fileName]?.remove(tag);
  }

  void toggleTag(String path, FileTag tag) {
    if (hasTag(path, tag.label)) {
      removeTag(path, tag);
    } else {
      addTag(path, tag);
    }
  }

  bool hasTag(String path, String tagLabel) {
    return getTagsForFile(path).any((t) => t.label.toLowerCase() == tagLabel.toLowerCase());
  }

  List<String> getFilesWithTag(String tagLabel) {
    final List<String> matched = [];
    _tagsByPath.forEach((path, tags) {
      if (tags.any((t) => t.label.toLowerCase() == tagLabel.toLowerCase())) {
        matched.add(path);
      }
    });
    return matched;
  }
}
