# دوّرها (Environmental Challenges): source bundle, version 0.4.1+11

Android app (Flutter): waste scanner, education, games, prices, collection-centre map, pickup request, Arabic and English. Free-only project.
Read `TECHNICAL_RESULTS.md` (what is tested and what is not), `BUILD.md`, `THIRD_PARTY_NOTICES.md`.

Folders: `source/` (app source, assets, tests, the bundled model), `plugins/onnxruntime/` (patched Dart and Android glue), `scripts/` (build and library scripts), `ml_scripts/make_icon.py` (generates the app icon), `source/docs/source_records/el_salam_candidate.json` (a held map candidate that tests use as a dialog fixture; it is not on the map).

0.4.1+11 changes against 0.4.0+10: map markers show the place name under the pin; the pin tip is drawn on the coordinate (it was centred, so it appeared too far north); the Katameya Downtown Mall pin uses the OpenStreetMap mall point. The scanner and model are unchanged (model sha256 6ef8f7f4d84395af7458731ead9d3f8aaf5ff54d49cfeab33a0f278b655e00d7).
The APK built from this source is `dawwarha-v0.4.1.apk`, sha256 7bc59604cfbc7f13ca87cdf5b7f7554c46c28cb4c4394095d926662ed17cf438 (a rebuild will not be byte-identical). Same package name as earlier builds, higher version code, debug signing key, so it installs over older builds. Firebase is used for login only; the API key is supplied at build time (see BUILD.md).

Known limits: low scanner accuracy on real photos, no organic or battery recognition, never tested on an Android phone, Alexandria has 3 of the 10 requested map pins (7 short), Arabic text needs a native read.
