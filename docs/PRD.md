# SoundSwitch: Product Requirements and Technical Implementation

**Category:** Smart Living  
**Tagline:** Make ordinary appliances trigger smart actions.  
**Document version:** 1.0 — 4 October 2026  
**Status:** Research-backed specification; implementation and device benchmarks have not been performed.  
**Working name:** SoundSwitch. Chimey can replace the name without changing the architecture.

## 1. Product vision

We’re building a phone app that helps people notice useful sounds around them and turn those sounds into actions. A washing machine finishes, a doorbell rings, or a timer goes off; the phone recognises the event and delivers the response the user chose.

We want the app to understand a growing variety of sounds, including sounds users teach it themselves. For unfamiliar sounds, we will combine on-device acoustic analysis, an audio-capable language model running on the phone, and optional internet research to offer possible explanations. The user can confirm an interpretation and create a reusable sound profile.

The core interaction is **teach → listen → recognise → act → improve**.

### Binding requirements from the brief

- Flutter and Dart for the application.
- TensorFlow Lite technology for local sound processing. We interpret “tensorlight” as **TensorFlow Lite, now called LiteRT**, rather than a separate library.
- An audio-capable LLM must execute on the mobile device in the full-feature configuration.
- Internet connectivity must help identify and contextualise unfamiliar sounds.
- Continuous live recognition and responsive actions.
- No Python in application code, backend services, model preparation scripts, training, evaluation, or build steps.

### Planning assumptions

- Android on an iQOO phone is the first release target. Flutter preserves a path to iOS, but iOS background recording and model integration require their own implementation and validation.
- The exact iQOO model, RAM, Android version, chipset, and available storage are unknown. Hardware requirements below are qualification targets, not verified compatibility claims.
- Initial actions are convenience notifications, vibrations, and a connected LED.
- A production release is broader than the original 48-hour demonstration. The demonstration scope and full-product scope are explicitly separated.

## 2. Research findings and their design consequences

### 2.1 Local acoustic classification

YAMNet provides a useful baseline for broad acoustic categories. It predicts 521 AudioSet classes and provides 1,024-dimensional embeddings in the documented TensorFlow model. Its input is mono audio at 16 kHz. The model analyses approximately 0.96-second patches with a 0.48-second hop; the upstream implementation notes that the first patch needs approximately 975 ms of waveform. A shipped LiteRT artifact may expose different outputs or require additional padding, so its tensor contract must be inspected independently. [YAMNet source documentation](https://github.com/tensorflow/models/blob/master/research/audioset/yamnet/README.md), [TensorFlow transfer-learning guide](https://www.tensorflow.org/tutorials/audio/transfer_learning_audio)

**Design consequence:** YAMNet is the baseline category detector and, when the shipped artifact exposes embeddings, the feature extractor for personal sound matching. It cannot identify every appliance or unique sound from its class vocabulary.

### 2.2 On-device language models that receive audio

Gemma 3n is designed for deployment on everyday devices and supports audio input. E2B and E4B describe effective parameter configurations; they do not establish total download size or complete multimodal memory requirements. [Gemma 3n overview](https://ai.google.dev/gemma/docs/gemma-3n)

LiteRT-LM provides an Android Kotlin API with audio content types and configurable audio processing backends. Its documentation warns that model initialization can be slow, so loading must happen asynchronously. [LiteRT-LM Android guide](https://ai.google.dev/edge/litert-lm/android)

**Design consequence:** Begin qualification with a preconverted, quantized, audio-enabled Gemma 3n E2B artifact. Evaluate environmental sound identification directly; speech transcription support alone does not prove that the model distinguishes household noises well. A text-only model receiving labels is an explanation engine, not an independent sound recogniser.

### 2.3 Flutter integration

Flutter supports native integration through platform channels and generated Pigeon interfaces. Google’s LiteRT-LM Flutter page points to a community-maintained package; the linked repository currently redirects from `flutter_gemma` to `flutter_edge_ai`. [Flutter platform channels](https://docs.flutter.dev/platform-integration/platform-channels), [LiteRT-LM Flutter guide](https://ai.google.dev/edge/litert-lm/flutter), [plugin repository](https://github.com/DenisovAV/flutter_edge_ai)

**Design consequence:** Use a small first-party Kotlin bridge for audio capture, LiteRT inference, and LiteRT-LM lifecycle. This gives the foreground service ownership of the hot path even when Flutter’s UI is inactive. The community plugin remains an integration alternative after its required audio features and lifecycle behaviour are verified.

### 2.4 Background microphone access

Android requires the appropriate microphone foreground-service type and permissions. Microphone access is subject to while-in-use restrictions; starting a microphone service from the background or boot receiver is generally restricted. A foreground service can continue microphone capture after a valid user-initiated start. [Android foreground-service types](https://developer.android.com/develop/background-work/services/fgs/service-types)

**Design consequence:** Start listening from a visible user action, show a persistent status notification, and accurately report interruptions. No invisible always-on startup promise.

### 2.5 Internet assistance

Gemini’s audio documentation supports analysis of non-speech sounds, and its search grounding feature can provide retrieved context with citations. These are separate capabilities; their combination must be verified for the selected API/model. [Gemini audio understanding](https://ai.google.dev/gemini-api/docs/audio), [Google Search grounding](https://ai.google.dev/gemini-api/docs/google-search)

**Design consequence:** The server can optionally analyse an explicitly shared short clip and separately research sound descriptions or appliance manuals. Text-only search cannot establish what an unheard recording contains.

## 3. Recognition promise

We will accept a wide range of sounds for analysis. We will return a supported classification, a personalised match, possible explanations, or an explicit unknown result.

“Literally any sound with accurate classification” is not a measurable or achievable guarantee. Different sources can produce acoustically similar sounds; the phone may not hear distant events; overlapping noise can obscure evidence; a beep alone may not reveal appliance identity or meaning. Neither internet access nor a larger LLM resolves missing acoustic evidence reliably.

The implementation must support four distinct outcomes:

| Outcome | Meaning | Allowed behaviour |
|---|---|---|
| Personal match | Audio matches an enrolled profile at a validated threshold | Execute its configured rule |
| Supported category | Acoustic evidence supports a known broad class | Show category; execute only a separately validated category rule |
| Possible explanation | Local audio model or online analysis proposes a source | Show uncertainty and alternatives; offer enrolment |
| Unknown / mixed | Evidence is insufficient or conflicting | Abstain; offer a longer recording or user label |

The app must distinguish “a repeating electronic beep” from “your washing machine has finished.” The second statement requires a validated personal profile or independent appliance-specific evidence.

## 4. Users and use cases

### Primary users

- People who wear headphones or become absorbed in work.
- Deaf and hard-of-hearing users who prefer visual or haptic cues.
- People using conventional appliances without smart-home integration.
- Makers who want to map a sound to a simple connected accessory.

### Core user stories

1. As a user, we want to teach the app our washing machine’s completion tone so that we can receive a recognisable alert.
2. As a user, we want different sounds to produce different vibration patterns so that we can distinguish events without looking at the screen.