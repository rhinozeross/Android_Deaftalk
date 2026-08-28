/// Ein einzelner Chat-Eintrag (entspricht der Java-Klasse `Eintrag`).
///
/// Die Auswahl ("markiert") ist reiner UI-Zustand und liegt daher nicht mehr
/// im Modell, sondern im Screen (ausgewählter Index).
class Eintrag {
  String eintrag; // der Nachrichtentext
  bool fromMeOrYou; // true = Ich, false = Gast

  Eintrag({
    this.eintrag = 'Hier ist nichts drin',
    this.fromMeOrYou = true,
  });

  /// Anzeige-String wie im Original: "Ich/Gast: text"
  @override
  String toString() => '${fromMeOrYou ? 'Ich' : 'Gast'}: $eintrag';

  Map<String, dynamic> toJson() => {
        'eintrag': eintrag,
        'fromMeOrYou': fromMeOrYou,
      };

  factory Eintrag.fromJson(Map<String, dynamic> json) => Eintrag(
        eintrag: json['eintrag'] as String? ?? '',
        fromMeOrYou: json['fromMeOrYou'] as bool? ?? true,
      );
}
