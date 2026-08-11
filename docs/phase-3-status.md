# Phase 3 – Status

Stand: 11. August 2026

## Implementierter Stand

- DCS-030: privater Übungskatalog mit Draft, Publish, neuer Version, Suche und Archivierung
- DCS-031: mehrere Content-Locales, Reviewstatus und deterministischer sichtbarer Fallback
- DCS-032: versionierte Vorlagen, sortierbare Übungen und Dauerabweichung
- DCS-033: Content-Pack-v1, SHA-256-Prüfsumme, Metadaten-/Referenzvalidator und atomarer Import
- freigegebenes Foundation-Pack 1.0.0 mit fünf Übungen (DE/EN) und zwei Vorlagen
- Katalog-Tab für iPhone und iPad

## Verifikation

- [x] JSON syntaktisch valide
- [x] Pack-Mengen, Locales und Vorlagendauern statisch geprüft
- [x] Swift-6-Zwischenbuild vor UI/Testintegration erfolgreich
- [x] vollständiger Build und 42 Swift-Testing-Tests in 11 Suites erfolgreich
- [x] Phase-3-UI-Smoke auf iPhone 16 / iOS 18.6 erfolgreich
- [x] Phase-3-UI-Smoke auf iPad Pro 11-inch (M4) / iOS 18.6 erfolgreich

Der UI-Smoke startet den Katalog über `--phase3-uitesting` deterministisch und
prüft sprachneutral das geladene Foundation-Pack sowie das Anlegen und Wiederfinden
einer privaten Übung. Die vollständige Suite deckt zusätzlich die bestehenden
Phase-0- bis Phase-2-Verträge ab.

## Grenzen

- Keine Cloud-, StoreKit-, Termin- oder Berichtsfunktion vorgezogen.
- Veröffentlichte Versionen sind unveränderbar; Änderungen erzeugen neue Versionen.
- Fehlende Übersetzungen werden markiert und niemals erfunden.
