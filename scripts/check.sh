#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

mkdir -p .build/module-cache .build/DerivedData

jq empty \
  PantheonPageExtension/Resources/manifest.json \
  PantheonPageExtension/Resources/rules.json

if command -v node >/dev/null 2>&1; then
  node --check PantheonPageExtension/Resources/content.js
  node --check PantheonPageExtension/Resources/page.js
  node scripts/test_page_cleaner.js
else
  echo "Node.js not found; skipping standalone JavaScript syntax check."
fi

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
