# Bundled acoustic model

Source: Google YAMNet classification TFLite v1, Apache 2.0.
Download: https://www.kaggle.com/api/v1/models/google/yamnet/tfLite/classification-tflite/1/download
Upstream source: https://github.com/tensorflow/models/tree/master/research/audioset/yamnet
License retained alongside the model.

Original `1.tflite` SHA-256: `10c95ea3eb9a7bb4cb8bddf6feb023250381008177ac162ce169694d05c317de`.
Derived SHA-256: `fe3165b659377dcf4f8fcf92d526118f259c89ed81f2f09af7572ee7dce98fdf`.

Reproduce with Node (no Python):

```
node tools/prepare-yamnet.mjs /path/to/1.tflite android/app/src/main/assets/models/yamnet.tflite
node tools/inspect-model.mjs android/app/src/main/assets/models/yamnet.tflite
```

The source has float32 waveform input `[15600]` and float32 class output `[1,521]`. The derived artifact additionally exposes its existing mean feature tensor 115, int8 `[1,1,1,1024]`. The script changes only the subgraph output vector; operators, buffers, weights and quantization are unchanged. Runtime dequantization uses the tensor's scale and zero point. Profiles use the versioned feature identifier `yamnet-embedding-v1`, never generic class-score vectors.

The capture service uses 16 kHz mono PCM, 15,600-sample windows and 7,680-sample hops. It rejects silent personal matches, ambiguous enrolled matches, disabled/unvalidated profiles, and cooldown repeats. Category outputs cannot trigger appliance-specific actions. Acoustic enrollment uses three repeated examples plus a room reference; it is initial calibration rather than a claim of recognition accuracy across every environment.

The portable CPU kernels are explicitly selected. The emulator's default XNNPACK delegate crashed with SIGILL during allocation, before model inference. Hardware acceleration needs separate device qualification.

Instrumentation compares the derived classifier's best score with the original artifact on identical PCM. The original is retained only in Android test assets, excluded from the shipped app.
