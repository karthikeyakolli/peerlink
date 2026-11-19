/// Lightweight cross-platform file item descriptor.
class FileItem {
  final String name;
  final String path;
  final int size;
  final DateTime modified;

  const FileItem({
    required this.name,
    required this.path,
    required this.size,
    required this.modified,
  });
}
