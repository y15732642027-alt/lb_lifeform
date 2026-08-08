import 'package:flutter_test/flutter_test.dart';
import 'package:lamp_companion/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const HermesCompanion());
    expect(find.byType(HermesCompanion), findsOneWidget);
  });
}
