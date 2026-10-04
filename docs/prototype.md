# Chimey UI prototype

## Scope

The supplied SoundSwitch brief provides the product context; the project is named chimey. Flutter/Dart is required. No Python is used. This delivery is UI only: recognition, LiteRT, audio LLMs, internet identification, background listening, LEDs, and system notifications are outside scope. Demo responses and actions are simulated.

## Visual design

A near-black full-screen canvas, generous typography, sparse controls, and continuous cyan, violet, pink, and amber light at the perimeter. A central listening visualization and conversational status responses. Cyan is the utility accent.

Aurora (https://github.com/tornikegomareli/Aurora) is the reference: animated anchored colors, a warped rounded-rectangle distance field, soft inward glow, and a settling burst. Implement a Flutter fragment shader; SwiftUI is incompatible with the required Flutter platform. This is a visual adaptation, not a claim of pixel-identical Apple rendering.

## Interactions

Listen, Sounds, and Activity views. Pause/resume listening; select household demo events; control demo direction, level, and frequency. Louder directional energy increases local wave density and amplitude. Teach named profiles through a simulated enrollment flow and toggle their demo response. Profiles are session-only.

A foreground microphone option will request permission on explicit user action and analyze PCM locally for RMS, relative dBFS, dominant frequency, and frequency bands. Audio is never uploaded or saved. A single microphone cannot reliably locate sounds, so live energy is distributed equally around edges. Demo directions remain labeled. Stop capture on inactivity, pause, navigation away, or disposal. Honor reduced motion.

## Delivery sequence

1. Scaffold/name Flutter project; verify, commit and push.
2. Listening interface, shader, navigation, profiles, demo responses; verify, commit and push.
3. Foreground audio and spectral analysis; verify, inspect responsive rendering, document limits, commit and push.

Validate with flutter analyze, flutter test, release web build, and desktop/phone browser interactions. Report native build or device verification limits explicitly.
