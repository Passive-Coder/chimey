# chimey

A Flutter UI prototype for noticing useful sounds around you. A flowing Apple Intelligence-style perimeter glow reacts to audio level and frequency, with conversational environment responses.

## Try it

```sh
flutter pub get
flutter run -d chrome
# or connect your phone:
flutter run
```

- **Listen:** pause/resume, try Quiet room, Doorbell, Laundry, or Unknown, and adjust demo level, frequency, and direction.
- **Use microphone:** explicit permission-based foreground audio capture. Local PCM analysis drives the glow, sound field, relative dBFS meter, dominant frequency, and 32-band spectrum. Pause, change views, or leave the app to stop capture. Return to demo with **Use demo**.
- **Sounds:** add a named demo sound, toggle profiles, and choose a simulated response.
- **Activity:** review or clear demo events. Profiles and activity last for the session only.

## Prototype boundaries

Only the UI and audio-reactive visualization are implemented. Sound classification, training, LiteRT, on-device LLMs, internet identification, background monitoring, appliance actions, notifications, vibrations, and LEDs are not implemented. Demo responses are labeled and no device action is executed. Live status describes measured loudness, not a recognized event.

A single microphone cannot reliably locate a sound. Directional edge density uses **simulated** direction in demo mode; live microphone energy is equal on every edge. Live **dBFS** is relative digital amplitude, not calibrated environmental dB SPL. Frequency is the strongest FFT bin above the noise floor, not sound identification. No audio is saved or uploaded.

Microphone capture on web requires HTTPS or localhost and browser permission. Device/browser gain and sample-rate handling can affect readings. Native device microphone behavior needs hardware validation; this prototype makes no device-accuracy promise.

## Validate and build

```sh
flutter analyze
flutter test
flutter build web --pwa-strategy none
flutter build ios --simulator
flutter build apk --debug
```

Flutter 3.38.7 / Dart 3.10.7 was used. Web release, iOS simulator, and Android debug APK builds verified. All 14 tests pass. Physical-device microphone behavior has not been verified. Tests cover PCM amplitude/frequency/silence/chunk boundaries, permission/start cancellation and capture stop, UI responses, enrollment, and responsive layouts.

## Visual reference

[Aurora](https://github.com/tornikegomareli/Aurora) supplies the reference approach: anchored multicolor fields, a warped rounded-rectangle distance field, soft inward light, and a damped intro pulse. Chimey implements an original Flutter GLSL adaptation with directional audio uniforms rather than a SwiftUI dependency. It is an approximation of that visual language, not a pixel-identical Apple implementation. Reduced motion stops continuous animation; a gradient fallback supports renderers without fragment shaders.

See [prototype design and scope](docs/prototype.md).
