# DogCoach Studio

DogCoach Studio contains the Phase-0 batch-completion proof of concept and the Phase-1 technical foundation: Swift 6 strict concurrency, dependency injection, typed diagnostics, and a local SwiftData schema v1.

## Generate and build

Requirements: Xcode 16 or newer, XcodeGen, and an iOS 18 or newer simulator runtime.

```sh
xcodegen generate
xcodebuild -project DogCoachStudio.xcodeproj -scheme DogCoachStudio -sdk iphonesimulator build
```

Run the full local verification from the repository root:

```sh
./scripts/verify.sh
```

Run the `DogCoachStudio` scheme to open the deterministic demo scenario. No real customer or dog data is included.

## Scope

The product and execution contract is [PLAN.md](PLAN.md). Architecture decisions live in `docs/adr/`; current phase evidence is tracked in `docs/phase-1-status.md`. Phase-0 market-validation materials remain available in `docs/validation/`.
