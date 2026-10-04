import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/main.dart';

void main() {
  testWidgets('PeerLink shell renders all 7 primary navigation destinations',
      (WidgetTester tester) async {
    await tester.pumpWidget(const PeerLinkApp());

    expect(find.text('PeerLink'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Devices'), findsOneWidget);
    expect(find.text('Files'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Spaces'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Verify intent cards on Home tab
    expect(find.text('SEND'), findsOneWidget);
    expect(find.text('ACCESS'), findsOneWidget);
    expect(find.text('SYNC'), findsOneWidget);
    expect(find.text('BACKUP'), findsOneWidget);

    // Verify Desktop Local Node IPC card
    expect(find.text('Desktop Local Node IPC'), findsOneWidget);
    expect(find.text('DISCONNECTED'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
  });
}
