# Deaftalk

A communication aid that lets a deaf person and a hearing person talk to each
other on a single phone screen — by typing, by having text read aloud, and by
turning speech into text.

## English

### What it is
Deaftalk turns one phone into a shared conversation surface. Both people use the
same screen: messages are typed or dictated, tagged as **Me** or **Guest**, and
any selected message can be **read aloud** in the chosen language. The hearing
person can speak — their words are transcribed to text the deaf person can read.

### Who it's for
Deaf and hard-of-hearing people, and anyone who needs to bridge a
text ↔ speech gap in a face-to-face or over-the-line situation.

### Example use cases
- **Intercom / door entry system:** A voice crackles through the intercom asking
  who's there. As a deaf person you can't hear it — let Deaftalk transcribe what
  is said, type your answer, and have it read aloud back into the intercom.
- **Support hotline:** Calling a hotline is hard when you can't hear the agent.
  Put the call on speaker, let Deaftalk turn the agent's speech into text, type
  your reply, and have the app speak it into the call.
- **Counter / face-to-face:** At a desk, pharmacy, or authority office — hand the
  phone back and forth: one types, the other reads or listens.

### Features
- Shared chat list with **Me / Guest** tagging
- **Text-to-speech** — read a selected message aloud in a chosen language
- **Speech-to-text** — dictate into the input field
- Delete a single message or the whole history
- History is saved and restored automatically
- **Offline speech recognition** on Android via Vosk — works even without
  Google services (e.g. on LineageOS); iOS/Web use the system recognizer

### Platforms
Android, iOS and Web (Android is the primary, fully tested target).

### Build & run
```bash
flutter pub get
flutter run                 # run on a connected device
flutter build apk --release # build a release APK
```
Prebuilt APKs are available on the [Releases page](../../releases).

---

## Deutsch

### Worum es geht
Deaftalk macht aus einem Handy eine gemeinsame Gesprächsfläche. Beide Personen
nutzen denselben Bildschirm: Nachrichten werden getippt oder diktiert, als
**Ich** oder **Gast** markiert, und jede ausgewählte Nachricht kann in der
gewählten Sprache **vorgelesen** werden. Die hörende Person kann sprechen — ihre
Worte werden in Text umgewandelt, den die gehörlose Person lesen kann.

### Für wen
Gehörlose und schwerhörige Menschen — und alle, die eine Lücke zwischen
Text und Sprache überbrücken müssen, ob von Angesicht zu Angesicht oder am
Telefon.

### Beispiel-Anwendungsfälle
- **Gegensprechanlage / Türsprechanlage:** Aus der Sprechanlage fragt eine Stimme,
  wer da ist. Als gehörlose Person hörst du das nicht — lass Deaftalk das
  Gesagte in Text umwandeln, tippe deine Antwort und lass sie zurück in die
  Anlage vorlesen.
- **Support-Hotline:** Eine Hotline anzurufen ist schwierig, wenn man die
  Mitarbeiter:innen nicht hört. Stell den Anruf laut, lass Deaftalk die Sprache
  in Text umwandeln, tippe deine Antwort und lass die App sie in den Anruf
  sprechen.
- **Schalter / persönliches Gespräch:** Am Tresen, in der Apotheke oder beim Amt —
  das Handy hin und her reichen: einer tippt, der andere liest oder hört zu.

### Funktionen
- Gemeinsame Chat-Liste mit **Ich / Gast**-Markierung
- **Text-to-Speech** — ausgewählte Nachricht in gewählter Sprache vorlesen
- **Speech-to-Text** — ins Eingabefeld diktieren
- Einzelne Nachricht oder die ganze Historie löschen
- Historie wird automatisch gespeichert und wiederhergestellt
- **Offline-Spracherkennung** auf Android via Vosk — funktioniert auch ohne
  Google-Dienste (z. B. auf LineageOS); iOS/Web nutzen den System-Recognizer

### Plattformen
Android, iOS und Web (Android ist die primäre, vollständig getestete Plattform).

### Bauen & starten
```bash
flutter pub get
flutter run                 # auf angeschlossenem Gerät starten
flutter build apk --release # Release-APK bauen
```
Fertige APKs gibt es auf der [Releases-Seite](../../releases).
