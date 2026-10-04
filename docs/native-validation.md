# Android validation — 4 October 2026

Android API 35 arm64 emulator, Java 21, Flutter 3.38.7.

- Three instrumentation tests passed: real YAMNet PCM inference with 1,024-dimensional finite dequantized embeddings; service-side ambiguity/invalid-enrollment gates; user-visible activity starts microphone foreground service, capture continues after activity reaches CREATED, explicit stop releases service.
- Additional model instrumentation test passed: derived artifact's classifier score agrees with the original artifact on identical synthetic 1 kHz PCM within 1e-6.
- Flutter analysis and 23 existing/domain tests passed. Fresh preference-storage round trip also passed.
- The default XNNPACK delegate crashed with SIGILL on this emulator during tensor allocation. Portable CPU kernels resolved it. This is why acceleration is disabled until qualified.

These tests establish integration and lifecycle behavior on an emulator. They do not establish personal-sound accuracy, battery performance, calibrated SPL, spatial localization, physical notification/haptic delivery, LED compatibility, or audio LLM hardware qualification. Those remain in the requirements matrix.

Run native tests using the project's Java 21 toolchain:

```
cd android
JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home ./gradlew app:connectedDebugAndroidTest
```

A running API 26+ Android emulator/device is required. The app deliberately does not restart microphone access from boot or background after process death. Start listening from a visible user action.

## Assistance and runtime review regressions

The final assistance-stage run passed seven Android instrumentation tests and three native unit tests. Added cases cover unequal profile thresholds, immediate stop/replacement cycles, repeated service attachment followed by worker exit, missing audio-model artifact handling, session ownership, and bounded PCM/WAV buffering. Notification denial cannot prevent disabling a rule; LED completion persists across restart while retaining corrections. Flutter analysis is clean and all 32 Flutter tests pass; five Node tests verify the assistance HTTP contract using a mocked provider. iOS simulator and web builds pass.

The local LLM bridge uses actual audio bytes. A successful inference with an authorized Gemma artifact has not been demonstrated. Online provider calls and physical LED/haptic delivery have not been demonstrated. LED transport requires HTTPS, including a suitable bridge for devices offering only plain HTTP.

## Desktop and platform builds

[Platform CI for source commit 45308f2](https://github.com/Passive-Coder/chimey/actions/runs/37220564959) passed Linux, Windows, and macOS release builds, web release build, iOS simulator build, Flutter analysis and 32 Flutter tests, and five Node server tests. A local macOS release build also passed and the native animated UI was inspected. These results qualify build integration; they do not expand Android-only recognition/model capabilities to other platforms or establish physical device accuracy.

## Unfamiliar-sound and acoustic regression stage

All 38 Flutter tests passed with clean analysis. The full eight-test Android instrumentation suite and three native unit tests passed. `AcousticFixtureTest` passed actual model inference and service matching on synthetic signals; [acoustic validation](acoustic-validation.md) records inputs, artifact provenance, observed similarities, and reproduction steps. Labeling without a model still requires calibration, and an attempted microphone restart after corrupt primary storage is blocked. Full audio-model/provider/physical-device qualification remains pending.
