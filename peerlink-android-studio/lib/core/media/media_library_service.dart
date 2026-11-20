import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/file_item.dart';
import '../received_files_service.dart';
import '../system_media_scanner_service.dart';
import 'media_source_models.dart';

enum MediaSortOption {
  dateNewest,
  dateOldest,
  sizeLargest,
  nameAsc,
}

enum MediaViewDensity {
  comfortable,
  compact,
}

class MediaTimelineSection {
  final String dateTitle;
  final DateTime sectionDate;
  final List<MediaItem> items;

  const MediaTimelineSection({
    required this.dateTitle,
    required this.sectionDate,
    required this.items,
  });
}

/// Centralized manager for indexing, searching, filtering, and organizing
/// media items across Device Storage, Secure App Vault, and Paired Remote Peers.
class MediaLibraryService extends ChangeNotifier {
  MediaLibraryService._();
  static final MediaLibraryService instance = MediaLibraryService._();

  final SystemMediaScannerService _systemScanner = SystemMediaScannerService.instance;
  final ReceivedFilesService _vaultService = ReceivedFilesService.instance;

  List<MediaItem> _allItems = [];
  final Set<String> _favoriteIds = {};
  final Set<String> _selectedIds = {};

  MediaSortOption _sortOption = MediaSortOption.dateNewest;
  MediaViewDensity _viewDensity = MediaViewDensity.comfortable;
  String _searchQuery = '';
  MediaOrigin? _originFilter;
  MediaKind? _kindFilter;
  String? _selectedAlbumName;
  bool _favoritesOnly = false;
  bool _isLoading = false;

  bool get isLoading => _isLoading;
  List<MediaItem> get allItems => List.unmodifiable(_allItems);
  Set<String> get favoriteIds => Set.unmodifiable(_favoriteIds);
  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);
  MediaSortOption get sortOption => _sortOption;
  MediaViewDensity get viewDensity => _viewDensity;
  String get searchQuery => _searchQuery;
  MediaOrigin? get originFilter => _originFilter;
  MediaKind? get kindFilter => _kindFilter;
  String? get selectedAlbumName => _selectedAlbumName;
  bool get favoritesOnly => _favoritesOnly;

  bool isSelected(String id) => _selectedIds.contains(id);
  bool isFavorite(String id) => _favoriteIds.contains(id);

  void setSortOption(MediaSortOption sort) {
    _sortOption = sort;
    notifyListeners();
  }

  void setViewDensity(MediaViewDensity density) {
    _viewDensity = density;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query.trim().toLowerCase();
    notifyListeners();
  }

  void setOriginFilter(MediaOrigin? origin) {
    _originFilter = origin;
    notifyListeners();
  }

  void setKindFilter(MediaKind? kind) {
    _kindFilter = kind;
    notifyListeners();
  }

  void setSelectedAlbum(String? album) {
    _selectedAlbumName = album;
    notifyListeners();
  }

  void setFavoritesOnly(bool favs) {
    _favoritesOnly = favs;
    notifyListeners();
  }

  void toggleFavorite(String id) {
    if (_favoriteIds.contains(id)) {
      _favoriteIds.remove(id);
    } else {
      _favoriteIds.add(id);
    }
    // Update matching in-memory item
    final idx = _allItems.indexWhere((it) => it.id == id);
    if (idx != -1) {
      _allItems[idx] = _allItems[idx].copyWith(isFavorite: _favoriteIds.contains(id));
    }
    notifyListeners();
  }

  void toggleSelection(String id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    notifyListeners();
  }

  void selectAll(List<MediaItem> items) {
    for (final it in items) {
      _selectedIds.add(it.id);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedIds.clear();
    notifyListeners();
  }

  /// Scans both Device Storage and Vault, synthesizing unified MediaItems.
  Future<void> refreshMedia({bool forceSystemSync = false}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final items = <MediaItem>[];
      final seenPaths = <String>{};

      // 1. Scan System Device Storage
      final systemFiles = await _systemScanner.scanDeviceStorage(forceRefresh: forceSystemSync);
      for (final f in systemFiles) {
        if (!seenPaths.add(f.path)) continue;
        final kind = _detectKind(f.name);
        if (kind == null) continue;
        items.add(MediaItem(
          id: f.path,
          name: f.name,
          path: f.path,
          origin: MediaOrigin.deviceStorage,
          kind: kind,
          sizeBytes: f.sizeBytes,
          lastModified: f.lastModified,
          dateTaken: f.lastModified,
          isFavorite: _favoriteIds.contains(f.path),
        ));
      }

      // 2. Scan Secure App Vault
      final vaultFiles = await _vaultService.getReceivedFiles();
      for (final vf in vaultFiles) {
        if (vf.isDirectory) continue;
        if (!seenPaths.add(vf.path)) continue;
        final kind = _detectKind(vf.name);
        if (kind == null) continue;
        items.add(MediaItem(
          id: vf.path,
          name: vf.name,
          path: vf.path,
          origin: MediaOrigin.vaultStorage,
          kind: kind,
          sizeBytes: vf.sizeBytes,
          lastModified: vf.lastModified,
          dateTaken: vf.lastModified,
          isFavorite: _favoriteIds.contains(vf.path),
        ));
      }

      _allItems = items;
    } catch (e) {
      debugPrint('MediaLibraryService refresh error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  MediaKind? _detectKind(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.bmp') ||
        lower.endsWith('.heic') ||
        lower.endsWith('.avif')) {
      return MediaKind.photo;
    }
    if (lower.endsWith('.mp4') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.3gp') ||
        lower.endsWith('.flv') ||
        lower.endsWith('.wmv')) {
      return MediaKind.video;
    }
    if (lower.endsWith('.mp3') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.flac') ||
        lower.endsWith('.aac') ||
        lower.endsWith('.ogg') ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.opus')) {
      return MediaKind.audio;
    }
    return null;
  }

  /// Returns filtered and sorted items matching current criteria.
  List<MediaItem> get filteredItems {
    var result = _allItems;

    if (_favoritesOnly) {
      result = result.where((it) => it.isFavorite || _favoriteIds.contains(it.id)).toList();
    }

    if (_originFilter != null) {
      result = result.where((it) => it.origin == _originFilter).toList();
    }

    if (_kindFilter != null) {
      result = result.where((it) => it.kind == _kindFilter).toList();
    }

    if (_selectedAlbumName != null && _selectedAlbumName!.isNotEmpty) {
      result = result.where((it) => it.parentDirectoryName == _selectedAlbumName).toList();
    }

    if (_searchQuery.isNotEmpty) {
      result = result.where((it) => it.name.toLowerCase().contains(_searchQuery)).toList();
    }

    switch (_sortOption) {
      case MediaSortOption.dateNewest:
        result.sort((a, b) => b.dateTaken.compareTo(a.dateTaken));
        break;
      case MediaSortOption.dateOldest:
        result.sort((a, b) => a.dateTaken.compareTo(b.dateTaken));
        break;
      case MediaSortOption.sizeLargest:
        result.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
        break;
      case MediaSortOption.nameAsc:
        result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
    }

    return result;
  }

  /// Groups filtered items chronologically into timeline sections.
  List<MediaTimelineSection> get timelineSections {
    final items = filteredItems;
    final Map<String, List<MediaItem>> groups = {};
    final Map<String, DateTime> groupDates = {};

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final it in items) {
      final d = it.dateTaken;
      final itemDay = DateTime(d.year, d.month, d.day);
      String key;

      if (itemDay == today) {
        key = 'Today';
      } else if (itemDay == yesterday) {
        key = 'Yesterday';
      } else if (today.difference(itemDay).inDays < 7) {
        key = 'This Week';
      } else if (d.year == now.year) {
        key = _monthName(d.month);
      } else {
        key = '${_monthName(d.month)} ${d.year}';
      }

      groups.putIfAbsent(key, () => []).add(it);
      groupDates.putIfAbsent(key, () => itemDay);
    }

    return groups.entries.map((e) {
      return MediaTimelineSection(
        dateTitle: e.key,
        sectionDate: groupDates[e.key] ?? DateTime.now(),
        items: e.value,
      );
    }).toList();
  }

  /// Extracts list of unique album / folder names.
  List<String> get availableAlbums {
    final albums = <String>{};
    for (final it in _allItems) {
      albums.add(it.parentDirectoryName);
    }
    final list = albums.toList();
    list.sort();
    return list;
  }

  static String _monthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    if (month >= 1 && month <= 12) return months[month - 1];
    return '';
  }
}
