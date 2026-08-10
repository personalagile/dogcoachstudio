# Phase 2 – Status

Stand: 10. August 2026

## Ergebnis

Phase 2 (DCS-020 bis DCS-023) ist implementiert. Personen, Hunde, Kontaktrollen,
Erstgespräch-Drafts und Trainingsziele werden lokal in SwiftData gespeichert und
über eine adaptive iPhone-/iPad-Navigation bedient.

### DCS-020 – Kundenstamm

- [x] Kunden anlegen und bearbeiten
- [x] Suche mit Normalisierung und Archivfilter
- [x] Archivierung erhält verknüpfte Historie
- [x] physisches Löschen ist bei fachlichen Abhängigkeiten gesperrt

### DCS-021 – Hunde und Kontakte

- [x] Hunde anlegen, bearbeiten und archivieren
- [x] viele-zu-viele Kontaktrollen zwischen Kunden und Hunden
- [x] eindeutige Rolle je Kunde, Hund und Rollentyp
- [x] genau ein Primärkontakt, sobald Kontaktrollen existieren

### DCS-022 – Erstgespräch und Ziele

- [x] kundenfähige Intake-Felder und private Trainernotizen sind getrennte Typen
- [x] abbrechbares Autosave mit Recovery des neuesten Drafts
- [x] explizites Mapping verhindert private Inhalte in kundenfähigen Daten
- [x] Trainingsziele mit planned/active/paused/achieved/abandoned
- [x] persistente Statuswechsel und Abschlusszeitpunkte

### DCS-023 – Hundeakte und Navigation

- [x] adaptive `NavigationSplitView` für iPhone und iPad
- [x] Hundeakte mit Übersicht, Sicherheit, Kontakten, Intake und Zielen
- [x] klar markierte Platzhalter für spätere Termine, Historie und Pakete
- [x] Composition Root injiziert Persistenz, Clock und UUID-Erzeugung
- [x] stabile Accessibility-Identifier für die Kernabläufe

## Verifikation

- Swift-6-Strict-Concurrency-Typechecks für Domain und Persistenz
- 37 Swift-Testing-Tests in 10 Suites für CRUD, Suche, Archivierung,
  Rollen-Invarianten, Draft-Recovery/Privacy und Goal-Status/Persistenz
- 2 XCUITest-Smokes: Phase-0-Abschluss und Client → Hund → Intake → Ziel
- vollständiger Lauf auf iPhone 16 / iOS 18.6: `TEST SUCCEEDED` in 54,52 s
- adaptiver Phase-2-UI-Smoke auf iPad Pro 11″ (M4) / iOS 18.6:
  `TEST SUCCEEDED` (1/1); Sidebar und Add-Aktion sind beim Start exponiert
- keine CoreData-Collection-Warnungen im Abschlusslauf
- bestehender Phase-0-Abschluss-Smoke bleibt über `--phase0-demo` isoliert

## Grenzen und Abweichungen

- Keine Schema-v2-Änderung: Phase 2 verwendet die vorhandenen Schema-v1-Entitäten.
- Kein Cloud-Sync, Backend, Kundenportal, Termin-, Paket- oder Berichtsausbau.
- Intake erzeugt keine Diagnose, Klassifikation oder Empfehlung.
- Ein Draft aktualisiert die bestehende Intake-Entität; ein eigenständiger
  Publish-/Revisions-Workflow bleibt einer späteren Freigabe vorbehalten.
- Die offenen Produktvalidierungs-Gates aus Phase 0 bleiben dokumentiert und
  werden durch die technische Freigabe nicht als erhobene Evidenz dargestellt.
