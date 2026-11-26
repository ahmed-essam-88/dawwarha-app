#!/bin/bash
# Runs the exact flutter assemble step that "flutter build apk" would run, for both ABIs, so Gradle does not re-run the Dart compile while its own JVM is alive.
# Dart defines must equal, in the same order, what flutter build passes: the user's --dart-define (the API key) first, then build name/number from pubspec and the Flutter version facts. A mismatch makes Gradle re-run the Dart compile and run out of memory.
set -e
cd "$(dirname "$0")/../source"
KEY="$1"
M=$(flutter --version --machine)
j(){ python3 -c "import sys,json;print(json.load(sys.stdin)['$1'])" <<<"$M"; }
VER=$(sed -n 's/^version: *//p' pubspec.yaml); NAME=${VER%%+*}; NUM=${VER##*+}
D=("FIREBASE_API_KEY=$KEY" "FLUTTER_BUILD_NAME=$NAME" "FLUTTER_BUILD_NUMBER=$NUM" "FLUTTER_VERSION=$(j frameworkVersion)" "FLUTTER_CHANNEL=$(j channel)" "FLUTTER_GIT_URL=$(j repositoryUrl)" "FLUTTER_FRAMEWORK_REVISION=$(j frameworkRevision | cut -c1-10)" "FLUTTER_ENGINE_REVISION=$(j engineRevision | cut -c1-10)" "FLUTTER_DART_VERSION=$(j dartSdkVersion)")
DD=$(for x in "${D[@]}"; do printf '%s' "$x" | base64 -w0; printf ','; done | sed 's/,$//')
flutter --quiet assemble --no-version-check --depfile build/app/intermediates/flutter/release/flutter_build.d --output build/app/intermediates/flutter/release -dTargetFile=lib/main.dart -dTargetPlatform=android -dBuildMode=release -dTrackWidgetCreation=true -dTreeShakeIcons=true --DartDefines="$DD" -dFlavor= -dAndroidArchs="android-arm android-arm64" -dMinSdkVersion=24 android_aot_bundle_release_android-arm android_aot_bundle_release_android-arm64
