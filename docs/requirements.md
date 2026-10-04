# Full PRD coverage and acceptance

The current goal is the full product, superseding docs/prototype.md's old scope. The provided PRD is retained verbatim in PRD.md. Status is incomplete until runtime evidence proves each requirement.

| Requirement | Status | Evidence required |
|---|---|---|
| Project named chimey; Flutter/Dart | Implemented | manifests, analyze, native builds |
| Apple Intelligence-style audio-reactive UI | Prototype implemented | rendered UI + live audio on hardware |
| LiteRT acoustic processing/YAMNet | Missing | bundled licensed artifact, inspected contract, real inference |
| Personal sound enrollment and reusable matching | Missing | multi-example recording, calibrated match/abstention |
| Four recognition outcomes and safe rule gates | Missing | tests and actual recognition events |
| On-device audio-capable LLM full configuration | Missing | actual audio content inference on qualified device |
| Optional internet sound identification/context | Missing | consented clip analysis, separate research, citations |
| Continuous recognition, responsive actions | Missing | service capture/inference/action timing |
| Valid Android microphone foreground service | Missing | visible start, persistent notification, background runtime |
| Convenience notifications | Missing | real device delivery |
| Distinct vibration patterns | Missing | real device delivery and rule tests |
| Connected LED | Missing | configured transport and physical device acknowledgement |
| Confirmation/labeling/reusable unfamiliar profiles | Missing | hypothesis confirmation and enrollment flow |
| Improve/correct/re-enroll | Missing | persisted feedback and updated matching |
| Profiles/rules and listening interruption state | Missing | restart/recovery tests and hardware |
| No Python anywhere in delivery | Implemented so far | source/build/tool audit |
| Requested broad platform/device compatibility | Unverified | platform capability matrix, builds, hardware tests |

No calibrated SPL or spatial sound localization is promised without suitable hardware. Do not label model hypotheses as validated personal matches. Do not execute explanation-derived actions.
