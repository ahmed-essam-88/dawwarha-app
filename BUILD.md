# Build instructions (0.4.1+11)

Toolchain used for this build: Flutter 3.50.1 stable (framework ae9b586f34a8443573f82ef57c3bf914a908cbf7, Dart 3.14.0), JDK 17 (17.0.21), Android SDK platforms 34 and 36, build-tools 34.0.0 and 36.0.0, NDK 28.2.13676358, Gradle 9.5.0 (wrapper), Android Gradle Plugin 9.3.1. Dependencies are locked in `source/pubspec.lock`.

1. Install the Android native libraries (needs curl, unzip): `scripts/fetch_ort_android_libs.sh`. It downloads ONNX Runtime 1.32.0 from Maven Central, checks the published aar sha1 and the extracted libraries' sha256, and installs arm64-v8a and armeabi-v7a.
2. Build: `FIREBASE_API_KEY=<your Firebase web API key for project wasteapp-d683c> scripts/build_apk.sh`. The key is a client identifier for email/password login only. It is not stored in this bundle (the default in `source/lib/core/firebase_config.dart` is empty), and without it login cannot work. The APK path is printed at the end.
3. Machine with about 2 GB RAM and 1 CPU: set `~/.gradle/gradle.properties` to
   `org.gradle.jvmargs=-Xmx620m -XX:MaxMetaspaceSize=384m -XX:ReservedCodeCacheSize=32m -XX:+UseSerialGC -Xss512k`, `org.gradle.daemon=false`, `org.gradle.workers.max=1`, `kotlin.daemon.jvm.options=-Xmx192m`, then run `LOW_MEMORY=1 FIREBASE_API_KEY=... scripts/build_apk.sh`. This runs the Dart/AOT compile alone first (`scripts/assemble_aot_low_memory.sh`), because an out-of-memory kill happened when the Dart compiler and the Gradle JVM were alive together. Run one build at a time.
4. The release is signed with the debug keystore (`source/android/app/build.gradle.kts`). Use your own keystore for a store release.
5. Checks after a build: `unzip -l app-release.apk | grep libonnxruntime` (both ABIs), `zipalign -c -P 16 -v 4 app-release.apk`, `apksigner verify --print-certs`, `aapt dump badging` (versionCode 11, versionName 0.4.1, minSdk 24, label دوّرها). A rebuild will not be byte-identical.
6. Desktop tests: `cd source && flutter pub get && flutter test`. The real-model tests need `LD_LIBRARY_PATH` pointing at a directory with a desktop `libonnxruntime.so`; they skip otherwise (6 tests skip without it).
