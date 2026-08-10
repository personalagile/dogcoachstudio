#!/bin/sh
set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
DERIVED_DATA_PATH="${TMPDIR:-/tmp}/dogcoachstudio-derived-data"

cd "$PROJECT_ROOT"
xcodegen generate
xcodebuild \
  -quiet \
  -project DogCoachStudio.xcodeproj \
  -scheme DogCoachStudio \
  -destination "platform=iOS Simulator,name=iPhone 16,OS=18.6" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  clean test

