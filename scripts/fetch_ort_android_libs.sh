#!/bin/bash
# Downloads ONNX Runtime 1.32.0 Android libs from Maven Central, verifies them, and installs them into the plugin.
set -e
cd "$(dirname "$0")/../plugins/onnxruntime"
T=$(mktemp -d)
curl -fL -o "$T/ort.aar" https://repo1.maven.org/maven2/com/microsoft/onnxruntime/onnxruntime-android/1.32.0/onnxruntime-android-1.32.0.aar
echo "e66a7eab2d1ce3118eb0cfb75ef190c2f4a83024  $T/ort.aar" | sha1sum -c -
for abi in arm64-v8a armeabi-v7a; do
  mkdir -p android/src/main/jniLibs/$abi
  unzip -p "$T/ort.aar" jni/$abi/libonnxruntime.so > android/src/main/jniLibs/$abi/libonnxruntime.so
done
echo "cdb41e8b7d0e3cb5e000c705e9904979c3b11de6e4614d2e4398e04ae8dcb1bb  android/src/main/jniLibs/arm64-v8a/libonnxruntime.so
082422326f55cf41b97818a319175489cff44aadbc745d629ad30098079c8b55  android/src/main/jniLibs/armeabi-v7a/libonnxruntime.so" | sha256sum -c -
rm -rf "$T"
