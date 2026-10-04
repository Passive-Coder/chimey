# Real acoustic feature regressions

The fixture in `test/fixtures/yamnet-synthetic.json` was produced by the shipped YAMNet artifact on the API 35 arm64 emulator. Its SHA-256 is `fe3165b659377dcf4f8fcf92d526118f259c89ed81f2f09af7572ee7dce98fdf`, independently checked against the bundled model. Each signal is 15,600 PCM16 samples at 16 kHz; embeddings have 1,024 dimensions. No microphone recording or personal audio is in this fixture.

`AcousticFixtureTest.kt` generates three 1 kHz tones at amplitudes 0.35, 0.45, and 0.55 with different phases, a held-out 1 kHz tone, a 2 kHz tone, silence, and deterministic noise. It runs actual LiteRT inference and checks the service-side matcher. Dart tests use the resulting embeddings to exercise production enrollment calibration and recognition.

Observed cosine similarities:

| Check | Similarity |
|---|---:|
| Minimum leave-one-out positive similarity | 0.971509 |
| Maximum example-to-noise similarity | 0.466490 |
| Held-out repetition to enrolled examples | 0.992615 |
| Different 2 kHz tone to enrolled examples | 0.712351 |
| Silence to enrolled examples | 0.446457 |

Enrollment selected threshold 0.8. The held-out repetition matched; noise, silence, the different tone, a disabled profile, and colliding profiles did not authorize an action. These are controlled synthetic integration regressions, not appliance recognition, battery, calibrated SPL, or physical-device accuracy benchmarks.

Unfamiliar sounds can now enter user-labeled enrollment without a model explanation. The enrollment dialog still requires separate examples and a room reference. Entering a label alone does not create an actionable profile. Live unknown responses link to explanation or labeling.

Corrupt primary storage preserves the original data and native profile cache, stops native listening, and prevents microphone restart. Failed native synchronization or event-stream connection also disables listening readiness. A widget regression verifies that an attempted restart makes no native `start` call after failed initialization.

## Reproduce

Run `flutter test test/acoustic_matching_test.dart test/unfamiliar_sound_test.dart` for calibration, abstention, labeling, and restart gates. Native tests require an Android emulator/device. To regenerate the synthetic fixture without Gradle's test cleanup uninstalling the app:

```
cd android
JAVA_HOME=/path/to/jdk21 ./gradlew app:assembleDebug app:assembleDebugAndroidTest
cd ..
adb install -r build/app/outputs/apk/debug/app-debug.apk
adb install -r build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk
adb shell am instrument -w -e class app.chimey.chimey.AcousticFixtureTest app.chimey.chimey.test/androidx.test.runner.AndroidJUnitRunner
adb exec-out run-as app.chimey.chimey cat files/acoustic-fixtures.json > test/fixtures/yamnet-synthetic.json
```

The native exporter includes the model's actual artifact hash. Regenerate and requalify features when the artifact changes.
