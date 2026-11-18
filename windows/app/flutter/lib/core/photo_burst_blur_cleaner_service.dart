import 'package:flutter/foundation.dart';

class PhotoMetadata {
  final String path;
  final DateTime timestamp;
  final int sizeBytes;

  const PhotoMetadata({
    required this.path,
    required this.timestamp,
    required this.sizeBytes,
  });
}

class PhotoBurstCluster {
  final List<PhotoMetadata> photos;
  final PhotoMetadata bestPhoto;
  final List<PhotoMetadata> redundantPhotos;

  const PhotoBurstCluster({
    required this.photos,
    required this.bestPhoto,
    required this.redundantPhotos,
  });
}

class PhotoBurstBlurCleanerService extends ChangeNotifier {
  PhotoBurstBlurCleanerService._();
  static final PhotoBurstBlurCleanerService instance = PhotoBurstBlurCleanerService._();

  List<PhotoBurstCluster> clusterBurstPhotos(List<PhotoMetadata> photos) {
    if (photos.length < 2) return const [];

    final sorted = List<PhotoMetadata>.from(photos)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final clusters = <PhotoBurstCluster>[];
    List<PhotoMetadata> currentCluster = [sorted.first];

    for (int i = 1; i < sorted.length; i++) {
      final prev = sorted[i - 1];
      final curr = sorted[i];

      final diff = curr.timestamp.difference(prev.timestamp).abs();
      if (diff <= const Duration(seconds: 2)) {
        currentCluster.add(curr);
      } else {
        if (currentCluster.length >= 2) {
          clusters.add(_buildCluster(currentCluster));
        }
        currentCluster = [curr];
      }
    }

    if (currentCluster.length >= 2) {
      clusters.add(_buildCluster(currentCluster));
    }

    return clusters;
  }

  PhotoBurstCluster _buildCluster(List<PhotoMetadata> cluster) {
    // Pick the photo with largest byte size (highest sharp detail)
    final sortedByDetail = List<PhotoMetadata>.from(cluster)
      ..sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));

    final best = sortedByDetail.first;
    final redundant = sortedByDetail.sublist(1);

    return PhotoBurstCluster(
      photos: cluster,
      bestPhoto: best,
      redundantPhotos: redundant,
    );
  }
}
