#!/bin/bash
# Release build of the app (both ABIs). Run from anywhere.
# Needs: Flutter SDK + JDK 17 + Android SDK on PATH/ANDROID_HOME (see BUILD.md).
# FIREBASE_API_KEY (your own Firebase web API key for project wasteapp-d683c) is passed at build time and not stored in this bundle.
# LOW_MEMORY=1 runs the Dart/AOT compile first with no Gradle JVM alive (needed on about 2 GB RAM).
set -e
cd "$(dirname "$0")/../source"
: "${FIREBASE_API_KEY:?set FIREBASE_API_KEY}"
flutter pub get
ARGS=(--release --target-platform "${TARGET_PLATFORMS:-android-arm,android-arm64}" --no-shrink "--dart-define=FIREBASE_API_KEY=$FIREBASE_API_KEY")
if [ "${LOW_MEMORY:-0}" = 1 ]; then
  mkdir -p build/app/intermediates/flutter/release
  ../scripts/assemble_aot_low_memory.sh "$FIREBASE_API_KEY"
fi
flutter build apk "${ARGS[@]}"
echo "APK: $(pwd)/build/app/outputs/flutter-apk/app-release.apk"
