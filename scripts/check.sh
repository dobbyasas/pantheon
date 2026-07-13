#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

mkdir -p .build/module-cache .build/DerivedData

swift \
  -module-cache-path .build/module-cache \
  scripts/validate_rules.swift \
  PantheonBlocker/blockerList.json

xcodebuild \
  -project Pantheon.xcodeproj \
  -scheme Pantheon \
  -configuration Debug \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
