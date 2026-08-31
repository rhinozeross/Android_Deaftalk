import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/locale_controller.dart';

/// Einstellungen – aktuell: manuelle Sprachwahl (System / Deutsch / English).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});

  final LocaleController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final current = controller.locale?.languageCode ?? 'system';
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  l.settingsLanguage,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              RadioGroup<String>(
                groupValue: current,
                onChanged: (value) {
                  if (value == null) return;
                  controller.setLocale(
                    value == 'system' ? null : Locale(value),
                  );
                },
                child: Column(
                  children: [
                    RadioListTile<String>(
                      value: 'system',
                      title: Text(l.languageSystem),
                    ),
                    // Sprachnamen bewusst als Autonyme (nicht übersetzt).
                    const RadioListTile<String>(
                      value: 'de',
                      title: Text('Deutsch'),
                    ),
                    const RadioListTile<String>(
                      value: 'en',
                      title: Text('English'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
