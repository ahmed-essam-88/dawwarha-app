# Technical results and limits (0.4.1+11, 26 Nov 2026)

## What is verified, and how
| Item | Status |
|---|---|
| APK static checks: versionCode 11, versionName 0.4.1, label دوّرها, minSdk 24, arm64-v8a and armeabi-v7a ONNX Runtime libraries, `zipalign -c -P 16` and `zipalign -c 4` pass, `apksigner verify` passes (debug key), 13 map pins in the packaged centers.json, model sha256 6ef8f7f4d84395af7458731ead9d3f8aaf5ff54d49cfeab33a0f278b655e00d7 | checked on the built file, APK sha256 7bc59604cfbc7f13ca87cdf5b7f7554c46c28cb4c4394095d926662ed17cf438 |
| arm64 ELF LOAD alignment: libapp.so and libflutter.so 64 KB, libonnxruntime.so and libdatastore_shared_counter.so 16 KB | checked with readelf. The armeabi-v7a libraries were not checked for this |
| Desktop tests (Linux x86-64, `flutter test`): 76 pass, 6 skipped. The real-model test ran with a desktop ONNX Runtime library on the library path; the skipped ones need it | run on the working copy and from a clean extract of this bundle (see the delivery report) |
| Map renders with place-name labels, pins at their coordinates | desktop widget test, tile-less render. Layout only, not accuracy proof |
| Android device behaviour, 32-bit runtime, ONNX Runtime 1.32 on Android, low-RAM behaviour, launcher icon, the new map labels on a phone | NOT tested |
| Login, pickup message and GPS | the owner tested an installed earlier build himself (his statement); not re-tested |

## Scanner
Model: `source/assets/models/recyclenet-small.onnx` (provenance in THIRD_PARTY_NOTICES.md). Six outputs: cardboard, glass, metal, paper, plastic, trash. No organic, battery or non-waste output. App rule: softmax, top probability under 0.60 gives "unknown" (`source/lib/services/waste_classifier.dart`). Measured accuracy on real photos is low: on one reused set of outdoor litter crops the app answered correctly 228 of 1,706 times and said "unknown" 1,113 times; on a reused set of staged photos 436 of 1,168 correct, 479 unknown. These sets were reused during development, so the numbers are not a fresh validation, and the sets are not in this bundle. An optional larger experimental scanner exists in the code behind a build flag (off by default, not tested on a phone).

## Collection centres (13 pins: Cairo 10, Alexandria 3)
Orange rows use the coordinate published on each store.orange.eg shop page, with identity and e-waste acceptance from the One Circle list. Toby rows use the coordinate on Toby's store locator and the branch list on 2b.com.eg. Big Scrappers rows come from bigscrappers.com/stores. The Katameya Downtown Mall pin is the OpenStreetMap mall point (a mall-level pin, not the shop door). City Stars is also a mall-level pin. Each pin carries a source and a note saying hours and acceptance are not confirmed. Alexandria has 3 of the 10 requested places; no source with both a drop-off statement and a usable coordinate was found for the rest. `source/assets/data/directory.json` holds 8 address-only entries. Scope: Alexandria and Cairo. Map data © OpenStreetMap contributors (attribution is shown in the app).

## Other
Prices: 27 sourced rows, frozen at the owner's request, not a complete list.
