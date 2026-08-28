/// Ein einzelner Chat-Eintrag (entspricht der Java-Klasse `Eintrag`).
class Eintrag {
  String eintrag; // der Nachrichtentext
  bool markiert; // ausgewählt (im Original mit "X" markiert)
  bool fromMeOrYou; // true = Ich, false = Gast

  Eintrag({
    this.eintrag = 'Hier ist nichts drin',
    this.markiert = false,
    this.fromMeOrYou = true,
  });

  /// Anzeige-String wie im Original: "[X] Ich/Gast: text"
  @override
  String toString() {
    final mark = markiert ? 'X ' : '';
    final wer = fromMeOrYou ? 'Ich' : 'Gast';
    return '$mark$wer: $eintrag';
  }

  Map<String, dynamic> toJson() => {
        'eintrag': eintrag,
        'fromMeOrYou': fromMeOrYou,
      };

  factory Eintrag.fromJson(Map<String, dynamic> json) => Eintrag(
        eintrag: json['eintrag'] as String? ?? '',
        fromMeOrYou: json['fromMeOrYou'] as bool? ?? true,
        markiert: false,
      );
}
