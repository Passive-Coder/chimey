# Local audio reasoning and optional internet assistance

Android now imports a user-selected audio-enabled `.litertlm` file into app storage, asynchronously initializes a native LiteRT-LM engine with an audio backend, and sends **actual encoded WAV audio** with `Content.AudioBytes`. Capture/YAMNet inference remain on a separate worker. Load/unload are explicit; missing artifacts, unavailable memory, unsupported device ABI, or initialization/inference failures are surfaced. No text-only stand-in is presented as audio recognition.

The runtime is pinned to LiteRT-LM 0.10.2 (compatible Kotlin 2.2 toolchain). Gemma 3n E2B audio-enabled quantized artifact is the initial qualification target. Obtain it through its official Google distribution and satisfy the model's license requirements before importing. Full multimodal download size and memory are broader than its effective parameter count. This repository does not embed a multi-gigabyte model or claim that it runs on every phone.

The last eight seconds of 16 kHz mono PCM stay in a bounded in-memory ring and are cleared when listening stops. Local analysis sends that recording only to the device model. Online analysis requires a fresh confirmation describing the assistance server and Google Gemini as recipients. Text research separately shares only the entered description. No provider credential is embedded in Flutter. Client tokens are held only for the open assistance screen.

Local and online answers are labeled unconfirmed explanations and cannot execute rules. A user can confirm an interpretation, then enter normal acoustic enrollment. Three repeated examples and a room reference still must pass calibration before a personal profile can act. Confirmation of a language-model hypothesis alone never creates an actionable sound rule.

The Node server implements distinct audio and search requests with source attribution and search-suggestion display. Tests use a provider transport stub, not a claim that cloud inference ran. See server/README.md for credential setup and validation. On-device environmental-sound analysis still needs an audio-enabled artifact and a qualified Android device; the current emulator has approximately 2 GB of RAM and is not a full Gemma qualification target.

## Foreground recent audio on other platforms

Web, iOS and desktop targets now expose Start/Stop microphone in Understand a sound and can share their most recent foreground audio through the same configured service. Live listening also offers Understand this sound directly, preserving the current capture session. A bounded Dart ring retains at most eight seconds of 16 kHz mono PCM in memory, handles split sample bytes, and requires one second before creating a WAV. Stop, interruption, restart and backgrounding clear the buffer. Nothing is written to disk.

A fresh confirmation is required before obtaining the snapshot. Cancel sends nothing; stopping capture while the prompt is open prevents sharing stale audio. Tests verify these boundaries and that an online explanation creates neither a personal rule nor an action event. Actual live cloud responses and microphone behavior on each platform remain separate qualification requirements. Native recognition and on-device LLM inference still require Android.

References:
- https://ai.google.dev/gemma/docs/gemma-3n
- https://github.com/google-ai-edge/LiteRT-LM/tree/v0.10.2/kotlin
- https://ai.google.dev/gemini-api/docs/audio
- https://ai.google.dev/gemini-api/docs/google-search
