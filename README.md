# chimey

A Flutter app for noticing useful sounds, with an Apple Intelligence-inspired audio-reactive glow and conversational environment responses.

The full PRD implementation is in progress. Android includes a native microphone foreground service, bundled LiteRT/YAMNet inference, calibrated personal sound enrollment, persistent rules, notifications, distinct vibration patterns, and a configurable LED JSON POST. A separate native worker imports and runs an audio-enabled LiteRT-LM model. Optional Node assistance distinguishes explicitly shared audio analysis from text-only internet research.

## Try it

```
flutter pub get
flutter run
```

Choose **Use microphone** to start listening. On Android, listening continues across views and backgrounding with a persistent status notification. Stop it in the app or notification. Other currently built platforms provide foreground microphone visualization and opt-in recent-clip assistance. Demo scenes are clearly labeled and never execute a rule.

Open **Sounds → Manage personal sounds & real actions**. While listening on Android, record three separate repetitions and a room reference; only profiles passing calibration can act. Choose a notification, a distinctive vibration pattern, or an HTTPS LED endpoint. Correct events or re-record examples from the persistent sound library.

Open **Understand an unfamiliar sound** to import an audio-enabled Gemma 3n E2B `.litertlm` model, load it asynchronously, and analyze recent audio locally. Model explanations remain unconfirmed. A confirmed interpretation still needs acoustic enrollment before it can trigger a rule. The official model distribution is access-gated; obtain a licensed artifact before importing. Full audio-model execution is not yet qualified on hardware.

For optional online assistance, follow [server setup](server/README.md). Every clip or description request requires an explicit sharing confirmation. Provider credentials remain on the server, and the client token is held only for the open screen. Live cloud results await configured credentials.

## Compatibility and validation

Android 8+ supports the native recognition pipeline. Full audio reasoning requires a supported 64-bit device, suitable model artifact, and sufficient RAM/storage; it is not promised on every phone. Web, iOS, macOS, Windows, and Linux have responsive UI and foreground audio visualization paths, with recent-audio assistance and text internet research when a service is configured. Desktop release builds, web, and iOS simulator builds passed [platform CI](https://github.com/Passive-Coder/chimey/actions/runs/37220564959); macOS rendering was also checked locally. Native iOS recognition/background model integration remains unimplemented. See [acoustic regression evidence](docs/acoustic-validation.md), [platform capabilities](docs/compatibility.md), [requirement coverage](docs/requirements.md), [native test evidence](docs/native-validation.md), [model contract](docs/yamnet.md), and [audio assistance](docs/audio-assistance.md).

A single microphone cannot reliably locate sound. Directional edge density is simulated in demo mode; live mono energy drives all edges equally. dBFS is relative digital amplitude rather than calibrated environmental SPL.

```
flutter analyze
flutter test
flutter build web --pwa-strategy none
flutter build apk --debug
flutter build ios --simulator
flutter build macos
cd server && npm test
```

44 Flutter tests, five Node contract tests, native PCM/session tests, and Android instrumentation have passed. Actual Gemma audio inference, live cloud responses, physical haptics/LED delivery, and personal-sound accuracy still require runtime qualification. No Python is used in application, server, model preparation, tests, or build tooling.

[Aurora](https://github.com/tornikegomareli/Aurora) informed the original Flutter shader's anchored colors and warped perimeter glow. It is a visual adaptation, not a claim of pixel-identical Apple rendering. Inter is bundled with its OFL license.
