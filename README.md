# DogCoach Studio

DogCoach Studio is currently in Phase 0: product validation and a deliberately small SwiftUI proof of concept for the batch session-completion workflow.

## Generate and build

Requirements: Xcode 16 or newer, XcodeGen, and an iOS 18 or newer simulator runtime.

```sh
xcodegen generate
xcodebuild -project DogCoachStudio.xcodeproj -scheme DogCoachStudio -sdk iphonesimulator build
```

Run the `DogCoachStudio` scheme to open the deterministic demo scenario. No real customer or dog data is included.

## Scope

The product and execution contract is [PLAN.md](PLAN.md). Phase-0 boundaries are documented in [ADR 0001](docs/adr/0001-poc-boundaries.md). Validation materials live in `docs/validation/`.
