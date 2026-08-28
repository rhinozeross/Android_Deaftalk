import 'package:flutter_test/flutter_test.dart';

import 'package:deaftalk/main.dart';

void main() {
  testWidgets('App startet und zeigt die Grundelemente', (tester) async {
    await tester.pumpWidget(const DeaftalkApp());
    await tester.pump();

    expect(find.text('Deaftalk'), findsWidgets);
    expect(find.text('Text senden'), findsOneWidget);
    expect(find.text('ausgewählten Text vorlesen'), findsOneWidget);
  });
}
