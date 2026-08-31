import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'screens/chat_screen.dart';
import 'services/locale_controller.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final localeController = LocaleController();
  await localeController.load();
  runApp(DeaftalkApp(localeController: localeController));
}

class DeaftalkApp extends StatelessWidget {
  const DeaftalkApp({super.key, required this.localeController});

  final LocaleController localeController;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: localeController,
      builder: (context, _) {
        return MaterialApp(
          title: 'Deaftalk',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          locale: localeController.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ChatScreen(localeController: localeController),
        );
      },
    );
  }
}
