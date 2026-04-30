# aichat

A Flutter example chat app on top of [`llama_cpp_dart`](https://pub.dev/packages/llama_cpp_dart).
Runs local GGUF models on macOS, iOS, and Android with persona, multi-conversation,
and search support backed by SQLite (FTS5).

## Layout

```
aichat/
├── lib/
│   ├── main.dart
│   ├── data/        # SQLite schema + repos for personas / conversations / models
│   ├── llm/         # llama.cpp engine wrapper, prompt rendering, downloader
│   └── ui/          # screens, chat surface, settings, sidebar, etc.
├── android/ ios/ macos/   # platform shells
└── pubspec.yaml
```

## Prerequisites

- Flutter 3.x with the macOS / iOS / Android targets you intend to use
- A GGUF model. Anything `llama.cpp` can load works; multimodal models also need an mmproj.
- macOS only: a built `libllama.dylib` (the dependency is consumed via a relative `path:`
  in `pubspec.yaml` — adjust to wherever you've cloned `llama_cpp_dart` to).

## Run

```bash
flutter pub get
flutter run -d macos        # or: -d ios / -d android
```

Once the app is running, open **Settings → Models → Add model** to pick a GGUF
file from disk or download one from a URL.

### Optional dev shortcuts (macOS, debug builds)

To skip the "Add model" UI on first launch, point the app at a model that's
already on disk via `--dart-define`:

```bash
flutter run -d macos \
  --dart-define=AICHAT_LLAMA_DYLIB=/abs/path/to/libllama.dylib \
  --dart-define=AICHAT_DEV_MODEL=/abs/path/to/model.gguf \
  --dart-define=AICHAT_DEV_MMPROJ=/abs/path/to/mmproj.gguf   # optional
```

`AICHAT_LLAMA_DYLIB` is only needed on macOS, where the dylib isn't bundled
into the app via a framework. On iOS the library is statically linked; on
Android it's loaded as `libllama.so` from the APK.
