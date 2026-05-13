import 'package:flutter_test/flutter_test.dart';
import 'package:aptiquest/main.dart';

void main() {
  testWidgets('App shows splash then home', (WidgetTester tester) async {
    await tester.pumpWidget(const AptiQuestApp());

    expect(find.textContaining('Aptiquest'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Dungeon of Placements'), findsOneWidget);
  });
}
