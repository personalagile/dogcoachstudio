# ADR 0002: Modulgrenzen innerhalb des App-Targets

- Status: Angenommen für Phase 1
- Datum: 10. August 2026
- Geltungsbereich: DCS-010 und DCS-011

## Kontext

DogCoach Studio startet als native, local-first iPhone-/iPad-App mit einem kleinen Team und einem App-Target. Der Plan benennt fachliche Features und Domain Use Cases, verlangt für das MVP aber keine physischen Swift Packages. Zu frühe Paketgrenzen würden Build-Konfiguration, Zugriffsebenen und Abhängigkeitsverwaltung erhöhen, bevor ein messbarer Ownership- oder Buildzeit-Nutzen besteht.

SwiftData ist ein Implementierungsdetail der lokalen Persistenz. UI und fachliche Regeln dürfen nicht direkt davon abhängig werden. Gleichzeitig sind SwiftData-ModelContext und UI-Zustand Main-Actor-gebunden; diese Isolation muss an der Kompositions- und Repository-Grenze sichtbar bleiben.

## Entscheidung

### Ein Monolith mit expliziten Ordnergrenzen

Phase 1 verwendet einen App-Monolithen und die bestehenden Test-Targets. Es werden keine physischen Swift Packages oder zusätzlichen Framework-Targets eingeführt.

Die Quellstruktur folgt diesen logischen Grenzen:

```text
DogCoachStudio/
  App/                    App-Start, Root-Navigation, Composition Root
  Domain/
    Models/               fachliche Werttypen und Identitäten
    UseCases/             anwendungsbezogene Operationen
    Services/             fachliche Regeln über mehrere Aggregate
    Repositories/         Repository-Protokolle
  Data/
    SwiftData/            persistierte Modelle, Container, Mapping
    Repositories/         SwiftData-Implementierungen
  Features/
    Today/
    Clients/
    Dogs/
    Intake/
    Catalog/
    Templates/
    Scheduling/
    SessionCompletion/
    Packages/
    Reports/
    Settings/
  Shared/
    UI/                   kleine wiederverwendbare UI-Bausteine
    Localization/         gemeinsame Lokalisierungshilfen
    Utilities/            nur tatsächlich geteilte, fachneutrale Hilfen
  Resources/
```

Nicht jeder Ordner muss in Phase 1 bereits existieren. Ordner werden erst mit dem zugehörigen Ticket angelegt; die Struktur definiert Zielrichtung und erlaubte Abhängigkeiten.

### Abhängigkeitsrichtung

```text
App -> Features -> Domain
App -> Data -> Domain
Features -> Shared
Data -> Shared (nur fachneutrale Hilfen)
Domain -> keine UI- oder Persistenzschicht
```

- Features dürfen Domain-Protokolle und Use Cases verwenden, aber keine konkreten SwiftData-Repositories erzeugen.
- Data implementiert Domain-Repository-Protokolle und übernimmt Mapping zwischen Persistenz- und Domain-Typen.
- Feature-zu-Feature-Imports und globale mutable Zustände werden vermieden. Gemeinsamer Ablauf wandert nur bei nachgewiesener Wiederverwendung in Domain oder Shared.
- `Shared` ist kein Auffangordner für unklare Zuständigkeiten.

### Dependency Injection und Composition Root

Konkrete Implementierungen werden ausschließlich am App-Einstieg zusammengesetzt. Ein kleiner `AppDependencies`-Container hält langlebige Abhängigkeiten wie Repository-Implementierungen und Domain Services. Features erhalten nur ihre benötigten Use Cases beziehungsweise Protokolle über Initializer oder SwiftUI Environment.

- Produktions-, Preview- und Testabhängigkeiten verwenden dieselben Protokolle.
- Tests können In-memory/Fake-Repositories injizieren.
- Kein Service Locator und kein frei zugängliches globales Singleton.
- Der SwiftData-Container wird am Composition Root erzeugt und nicht innerhalb einer Feature View aufgebaut.

### SwiftData und MainActor

- Aufbau und Verwendung von `ModelContainer`/`ModelContext` sowie SwiftData-Repositories erfolgen Main-Actor-isoliert, solange Phase 1 keinen separat begründeten Background-Actor einführt.
- Repository-Protokolle und Implementierungen tragen die notwendige Actor-Isolation explizit; Aufrufer umgehen sie nicht mit `nonisolated(unsafe)` oder unchecked Sendability.
- Features sprechen SwiftData nicht direkt an. Domainwerte überschreiten die Data-Grenze über kontrolliertes Mapping.
- Lang laufende oder CPU-intensive Arbeit darf nicht im Main Actor verbleiben, erhält aber erst bei konkretem Bedarf eine eigene, Sendable-fähige Grenze.
- Eine spätere atomare Session-Completion wird als eigener Actor/Domain Service entschieden; DCS-010/011 ziehen diese Phase-4-Implementierung nicht vor.

## Folgen

Positiv:

- geringe Projekt- und Build-Komplexität in der frühen Produktphase;
- testbare Feature- und Domain-Grenzen ohne Produktionspaketierung;
- Persistenz kann ersetzt oder für CloudKit vorbereitet werden, ohne UI-Abhängigkeiten umzubauen;
- Swift-6-Actor-Isolation wird an klaren Schnittstellen sichtbar.

Nachteile:

- Ordnergrenzen werden nicht vom Compiler wie separate Module erzwungen;
- Disziplin und Architekturtests/Reviews müssen unerlaubte Abhängigkeiten verhindern;
- interne Symbole sind zunächst targetweit sichtbar.

## Überprüfung

Physische Packages oder Framework-Targets werden erst erwogen, wenn mindestens einer dieser Gründe messbar vorliegt:

- relevante inkrementelle Buildzeitverbesserung;
- unabhängige Ownership oder Releasezyklen;
- echte Wiederverwendung in einem weiteren Target;
- wiederkehrende Grenzverletzungen, die durch Compiler-Isolation besser verhindert werden.

Eine solche Änderung benötigt eine neue ADR. Sie darf nicht nebenbei in einem Feature-Ticket erfolgen.

