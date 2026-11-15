#!/usr/bin/env bash
# Run this once on your computer (Flutter installed) to check the whole app.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -d android ] && [ ! -d ios ]; then
  echo "==> Creating the android/ios platform folders (one time)"
  flutter create . --project-name chit_mate --org com.chitmate --platforms android,ios
  rm -f test/widget_test.dart   # the default sample test refers to a MyApp we do not have
fi

echo "==> flutter pub get"
flutter pub get

echo "==> Generating launcher icons"
dart run flutter_launcher_icons

echo "==> flutter analyze"
flutter analyze --no-fatal-infos

echo "==> flutter test"
flutter test

echo "All checks passed."
