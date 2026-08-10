# Phase 1 – Status und Abweichungen

Stand: 10. August 2026

## Freigabe und Phase-0-Abweichung

Der Nutzer hat Phase 1 ausdrücklich freigegeben. Die in `PLAN.md` vorgesehenen Phase-0-Evidenz-Gates sind dadurch nicht nachträglich erfüllt:

- 12 unabhängige Interviews, davon mindestens 3 außerhalb Deutschlands: offen
- dokumentierte Ist-Zeiten, Werkzeuge und Fehlerquellen: offen
- mindestens 4 konkrete, bepreiste Pilotzusagen: offen
- belastbarer Konkurrenz-Benchmark: offen
- dokumentiertes Go/Pivot/No-Go anhand realer Evidenz: offen

Phase 1 beginnt daher als bewusst autorisierte Abweichung. Produktvalidierung und technische Projektgrundlage sind getrennt zu bewerten. Offene Phase-0-Ergebnisse dürfen nicht erfunden oder als bestätigt bezeichnet werden. Sobald ein Kill-Kriterium belegt ist, muss die Implementierung gemäß Plan gestoppt und eskaliert werden.

## Ticketstatus

### DCS-010 – Xcode-Projekt und Targets

- [x] iOS/iPadOS 18+ und Swift 6 festgelegt
- [x] App-, Unit-Test- und UI-Test-Targets bauen
- [x] Strict Concurrency aktiv
- [x] String Catalog und automatische String-Extraktion vorhanden
- [x] keine Drittanbieter-Abhängigkeiten
- [x] lokale Basis-CI über `scripts/verify.sh` dokumentiert
- [x] Clean Build erfolgreich
- [x] Smoke Test erfolgreich

### DCS-011 – AppEnvironment und Modulgrenzen

- [x] Repository-, Clock-, UUID- und Export-Protokolle vorhanden
- [x] logische App-/Domain-/Persistence-/Infrastructure-Grenzen umgesetzt
- [x] Dependency Injection am Composition Root
- [x] SwiftData/MainActor-Isolation explizit
- [x] keine physischen Swift Packages ohne neuen Entscheid
- [x] Preview-/Testabhängigkeiten injizierbar
- [x] Architekturentscheidung in ADR 0002 dokumentiert

### DCS-012 – SwiftData Schema v1

- [x] 22 MVP-Entitäten als `VersionedSchema` v1.0.0 modelliert
- [x] optionale Beziehungen plus stabile UUID-Fremdschlüssel
- [x] keine SwiftData-Unique-Constraints als alleinige Domain-Sicherung
- [x] Domain-Validatoren für Pflichtbeziehungen, Rollen, Completion Tokens und Ledger
- [x] In-memory und file-backed Store
- [x] Schema-v1-Golden-Fixture
- [x] CRUD-, Beziehungs-, Lösch-, Collection-Roundtrip- und Neustarttests
- [x] persistenter, rein fiktiver Demo-Datensatz beim ersten Start

### DCS-013 – Logging und Fehlerrahmen

- [x] typisierte `AppError`- und `RecoveryAction`-Struktur
- [x] Fehler-Mapping getestet
- [x] OSLog nur mit geschlossenem, PII-freiem Ereigniskatalog
- [x] JSON-Diagnoseexport vorbereitet und mit Privacy-Canary getestet
- [x] lokalisierbare Nutzertexte für Fehler und Recovery

## Dokumentierte Entscheidungen

- [`adr/0002-module-boundaries.md`](adr/0002-module-boundaries.md): Monolith mit logischen Ordnergrenzen, gerichteten Abhängigkeiten, Composition-Root-DI und Main-Actor-isolierter SwiftData-Grenze.
- Physische Packages sind in Phase 1 bewusst ausgeschlossen; eine spätere Einführung verlangt messbaren Nutzen und eine neue ADR.

## Abweichungsprotokoll

| Datum | Abweichung | Autorisierung | Auswirkung | Folgemaßnahme |
|---|---|---|---|---|
| 10.08.2026 | Phase 1 vor Abschluss der realen DCS-001-Validierung gestartet | ausdrückliche Nutzerfreigabe | technische Arbeit erfolgt auf noch unbestätigten Produkthypothesen | Validierung weiterführen; Kill-Kriterien überwachen; keine Erfolgsbehauptung ohne Evidenz |

## Abschlussprüfung Phase 1

- [x] Acceptance Criteria von DCS-010 bis DCS-013 nachweislich erfüllt
- [x] relevante Builds und Tests mit Kommando und Ergebnis dokumentiert
- [x] keine neuen Compiler- oder SwiftData-Schemawarnungen
- [x] Accessibility- und Lokalisierungsbasis geprüft
- [x] Datenschutz-, Migrations- und Exportauswirkung bewertet
- [x] bekannte Risiken und verschobene Punkte dokumentiert
- [x] technischer Exit für Phase 1 erreicht; Phase 2 benötigt separate Nutzerfreigabe

## Build-/Testnachweise

- `./scripts/verify.sh` – Clean Build, 25 Swift-Testing-Tests und 1 XCUITest-Smoke auf iPhone 16 / iOS 18.6: erfolgreich.
- `xcodebuild ... -destination 'platform=iOS Simulator,name=iPad (A16),OS=18.6' build` – iPad-Build: erfolgreich.
- File-backed Store wurde geschlossen und neu geöffnet; Clients und codierte Collection-Attribute blieben erhalten.
- Die während der Entwicklung entdeckten Core-Data-Warnungen für Array-Attribute wurden durch persistente `Data`-Felder plus `@Transient`-Zugriffe vollständig beseitigt.

## Bekannte Risiken

- Produkt-Markt-Evidenz aus DCS-001 steht aus.
- Logische Ordnergrenzen sind innerhalb eines Targets nicht compilerseitig erzwungen.
- SwiftData-/CloudKit-Details bleiben späteren Tickets und dem vorgesehenen Sync-Spike vorbehalten.
- Schema v1 ist lokal validiert; echte Migrationen aus einer älteren Produktionsversion existieren naturgemäß noch nicht.
- Diagnoseexport ist technisch vorbereitet, aber noch nicht über eine Phase-6-Einstellungsoberfläche teilbar.

## Bewusst verschoben

- keine produktiven CRUD-Features aus Phase 2
- keine Katalog-/Vorlagenlogik aus Phase 3
- keine atomare persistente Session-Completion aus Phase 4
- kein CloudKit, StoreKit, Kalender, PDF oder vollständiger Datenexport
