import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deaftalk/main.dart';
import 'package:deaftalk/services/locale_controller.dart';

void main() {
  testWidgets('App startet und zeigt die Grundelemente', (tester) async {
    await tester.pumpWidget(DeaftalkApp(localeController: LocaleController()));
    await tester.pump();

    // sprachunabhängig: App-Titel, Zahnrad und das Senden-Icon
    expect(find.text('Deaftalk'), findsWidgets);
    expect(find.byIcon(Icons.send), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
  });
}
