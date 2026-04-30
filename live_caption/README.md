# live_caption

Live-camera image captioning on Android, powered by
[SmolVLM-500M](https://huggingface.co/HuggingFaceTB/SmolVLM-500M-Instruct)
running locally via [`llama_cpp_dart`](https://pub.dev/packages/llama_cpp_dart).

A frame is captured from the back camera, fed to SmolVLM with an mmproj
projector, and the streaming caption is rendered as an overlay. The HUD shows
load time, last latency, frame count, and the active accelerator.

## Layout

```
live_caption/
├── lib/
│   ├── main.dart            # camera + caption loop + overlay UI
│   ├── diagnostics.dart     # ring-buffer log shared by engine + camera code
│   └── llm/
│       ├── caption_engine.dart   # llama.cpp wrapper around SmolVLM
│       ├── model_assets.dart     # one-time copy of the bundled GGUFs to app dir
│       └── platform_config.dart  # libllama.so path + Hexagon/HTP env vars
├── assets/models/           # GGUFs bundled into the APK (see "Models" below)
└── android/ ios/ ...
```

## Prerequisites

- Flutter 3.x with the Android toolchain
- An Android device with a camera (the example targets Android only — see
  [`platform_config.dart`](lib/llm/platform_config.dart))
- The two SmolVLM GGUFs in `assets/models/` (see below)

## Models

The app expects two files in `assets/models/`:

- `SmolVLM-500M-Instruct-Q8_0.gguf`     — the language model (~417 MB)
- `mmproj-SmolVLM-500M-Instruct-Q8_0.gguf` — the vision projector (~104 MB)

Grab them from the
[SmolVLM-500M-Instruct GGUF release](https://huggingface.co/ggml-org/SmolVLM-500M-Instruct-GGUF).

These are referenced from `pubspec.yaml` as Flutter assets and copied to the
app's documents directory on first launch.

## Run

```bash
flutter pub get
flutter run -d <android-device>
```

Tap **Start** once the HUD shows `ready`. **Copy logs** dumps the diagnostics
buffer to the clipboard for debugging.
