# Platform capabilities

chimey uses capability gates rather than presenting unavailable functions as working. A build passing does not qualify microphone quality, model memory, or physical action delivery on every device.

| Platform | Responsive UI / demo | Live foreground audio | Personal recognition / actions | Local audio LLM | Build evidence |
|---|---|---|---|---|---|
| Android 8+ | Yes | Native microphone service | LiteRT/YAMNet and calibrated profiles; notification/vibration/HTTPS LED | Audio-enabled `.litertlm`, supported 64-bit CPU and sufficient memory | API 35 arm64 emulator integration passed |
| iOS | Yes | Record plugin, microphone permission | Not integrated | Not integrated | Simulator build passed |
| Web | Yes | Supported browser, microphone permission and secure origin | Not integrated | Not integrated | Release build and browser preview passed |
| macOS 10.15+ | Yes | AVFoundation; live physical Mac microphone and explicit stop verified | Not integrated | Not integrated | Local release capture/navigation check and CI release build passed |
| Windows | Yes | MediaFoundation through Record plugin | Not integrated | Not integrated | CI release build passed |
| Linux | Yes | PulseAudio-compatible service plus `parecord`/`pactl` | Not integrated | Not integrated | CI release build passed |

Text-only internet research is available through a configured assistance service on all targets. Recent-clip assistance is implemented on all six targets: Android reads its native eight-second buffer; other targets use a bounded foreground PCM buffer and expose Start/Stop microphone controls in Understand a sound. Only a fresh sharing confirmation obtains and sends a WAV snapshot. Stopping, interruption, or app backgrounding clears the foreground buffer. These paths have Flutter contract/lifecycle tests and build evidence; actual microphone quality and live provider responses still need per-platform qualification. Every online request requires explicit confirmation, and an explanation cannot execute a rule.

On Linux, install `pulseaudio-utils` (or your distribution's package providing `parecord` and `pactl`). The app streams PCM rather than recording a file, so this path does not use ffmpeg. Build dependencies include GTK 3, clang, CMake, Ninja, pkg-config, and the C++ toolchain. Desktop builds follow [Flutter's platform instructions](https://docs.flutter.dev/platform-integration/desktop).

Build on the target operating system with `flutter build macos`, `flutter build windows`, or `flutter build linux`. The platform workflow pins the tested Flutter version and action revisions; The [platform run for source commit 45308f2](https://github.com/Passive-Coder/chimey/actions/runs/37220564959) passed Linux, Windows, macOS, web, and iOS simulator builds, plus Flutter analysis/tests and server tests. Physical device coverage, sustained audio capture, screen-off/background interruption behavior, and personal-sound accuracy require additional qualification.

Mono input does not establish direction or calibrated environmental decibels. Live amplitude/frequency drive the animation; directional density remains explicitly simulated until spatial capture hardware is available.

The [macOS foreground capture check](native-validation.md#live-macos-foreground-capture) demonstrated changing microphone readings, assistance navigation, sharing cancellation and explicit stop. Other platform microphones and live provider responses still need runtime qualification.
