import 'package:flutter/material.dart';

/// Verschiebt den Inhalt beim Einblenden der Tastatur um deren Höhe nach oben,
/// statt das Layout zu stauchen. So behält z.B. ein Chatfenster seine Größe
/// und der obere Bereich wandert nach oben aus dem sichtbaren Bereich.
///
/// Voraussetzung: Das umgebende [Scaffold] muss
/// `resizeToAvoidBottomInset: false` setzen.
class KeyboardInsetShifter extends StatelessWidget {
  const KeyboardInsetShifter({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    return ClipRect(
      child: Transform.translate(
        offset: Offset(0, -keyboardInset),
        child: child,
      ),
    );
  }
}
