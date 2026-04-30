# imaged SDK examples

Sample apps showing how to use the [imaged](https://imaged.dev) computer-vision
SDK across platforms, plus an example of running local LLMs via
[`llama_cpp_dart`](https://pub.dev/packages/llama_cpp_dart).

| Example | Stack | What it does |
| --- | --- | --- |
| [`ObjectDetector/`](ObjectDetector/) | Swift / SwiftUI / macOS | YOLO object detection on the macOS webcam via AVFoundation. |
| [`ObjectDetector-ios/`](ObjectDetector-ios/) | Swift / SwiftUI / iOS | Same example, iOS build. |
| [`ObjectDetector-android/`](ObjectDetector-android/) | Kotlin / Jetpack Compose / Android | Same detector, on Android with CameraX. |
| [`ObjectDetector-python/`](ObjectDetector-python/) | Python 3 / OpenCV / macOS | Webcam YOLO detection through the SDK's Python bindings. |
| [`aichat/`](aichat/) | Flutter (macOS / iOS / Android) | Local-LLM chat app over `llama_cpp_dart`, with personas, multi-conversation, and FTS search. |
| [`live_caption/`](live_caption/) | Flutter / Android | Live camera captioning with SmolVLM-500M via `llama_cpp_dart`. |

Each example has its own `README.md` with platform-specific setup. The SDK
license JWT embedded in the source files is a shared test token good through
2027 — replace it with your own when you mint one.
