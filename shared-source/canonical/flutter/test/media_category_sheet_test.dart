import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/design_system/components/media_category_sheet.dart';

void main() {
  group('MediaCategorySheet Tests (Feature B)', () {
    testWidgets('renders all 6 categories with correct titles and icons', (tester) async {
      MediaCategory? selectedCategory;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaCategorySheet(
              onCategorySelected: (cat) => selectedCategory = cat,
            ),
          ),
        ),
      );

      // Verify category titles
      expect(find.text('Photos & Images'), findsOneWidget);
      expect(find.text('Videos'), findsOneWidget);
      expect(find.text('Music & Audio'), findsOneWidget);
      expect(find.text('Documents'), findsOneWidget);
      expect(find.text('Archives & Backups'), findsOneWidget);
      expect(find.text('Browse All Storage'), findsOneWidget);

      // Tap on Photos
      await tester.tap(find.text('Photos & Images'));
      await tester.pump();
      expect(selectedCategory, equals(MediaCategory.photos));

      // Tap on Documents
      await tester.tap(find.text('Documents'));
      await tester.pump();
      expect(selectedCategory, equals(MediaCategory.documents));

      // Tap on Archives
      await tester.tap(find.text('Archives & Backups'));
      await tester.pump();
      expect(selectedCategory, equals(MediaCategory.archives));
    });

    testWidgets('displays review shelf when currentSelection is non-empty', (tester) async {
      MediaItemInfo? removedItem;
      bool clearedAll = false;

      final sampleItems = [
        const MediaItemInfo(
          pathOrUri: 'content://media/external/images/media/101',
          name: 'vacation_photo.jpg',
          sizeBytes: 2500000,
          category: MediaCategory.photos,
        ),
        const MediaItemInfo(
          pathOrUri: 'content://com.android.providers.downloads/document/202',
          name: 'project_spec.pdf',
          sizeBytes: 1048576,
          category: MediaCategory.documents,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaCategorySheet(
              currentSelection: sampleItems,
              onCategorySelected: (_) {},
              onItemRemoved: (item) => removedItem = item,
              onClearAll: () => clearedAll = true,
            ),
          ),
        ),
      );

      // Verify selection count and aggregate size
      expect(find.text('Selected: 2 items'), findsOneWidget);
      expect(find.textContaining('vacation_photo.jpg'), findsOneWidget);
      expect(find.textContaining('project_spec.pdf'), findsOneWidget);

      // Check Clear All button
      expect(find.text('Clear All'), findsOneWidget);
      await tester.tap(find.text('Clear All'));
      await tester.pump();
      expect(clearedAll, isTrue);

      // Find and tap remove icon for first item
      final removeButtons = find.byIcon(Icons.close);
      expect(removeButtons, findsNWidgets(2));
      await tester.tap(removeButtons.first);
      await tester.pump();
      expect(removedItem?.name, equals('vacation_photo.jpg'));
    });

    test('MediaItemInfo formats size correctly', () {
      const itemUnknown = MediaItemInfo(
        pathOrUri: 'uri1',
        name: 'test',
        sizeBytes: 0,
        category: MediaCategory.allFiles,
      );
      expect(itemUnknown.formattedSize, equals('Unknown size'));

      const itemBytes = MediaItemInfo(
        pathOrUri: 'uri2',
        name: 'test',
        sizeBytes: 512,
        category: MediaCategory.allFiles,
      );
      expect(itemBytes.formattedSize, equals('512 B'));

      const itemKb = MediaItemInfo(
        pathOrUri: 'uri3',
        name: 'test',
        sizeBytes: 2048,
        category: MediaCategory.documents,
      );
      expect(itemKb.formattedSize, equals('2.0 KB'));

      const itemMb = MediaItemInfo(
        pathOrUri: 'uri4',
        name: 'test',
        sizeBytes: 5242880,
        category: MediaCategory.videos,
      );
      expect(itemMb.formattedSize, equals('5.0 MB'));

      const itemGb = MediaItemInfo(
        pathOrUri: 'uri5',
        name: 'test',
        sizeBytes: 1073741824 * 2,
        category: MediaCategory.archives,
      );
      expect(itemGb.formattedSize, equals('2.00 GB'));
    });
  });
}
