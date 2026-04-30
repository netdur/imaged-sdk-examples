# ObjectDetector — macOS

Live-camera YOLO object detection with the imaged SDK on macOS, written in
Swift / SwiftUI / AVFoundation.

## Layout

```
ObjectDetector/
├── ObjectDetector.xcodeproj
├── ObjectDetector/
│   ├── ObjectDetectorApp.swift
│   ├── ContentView.swift
│   ├── CameraDetector.swift
│   ├── Assets.xcassets
│   └── yolo26x.onnx        # YOLO model — you provide this (see below)
└── imaged.xcframework      # imaged SDK — you provide this (see below)
```

## Get the model and SDK

Neither file is checked into this repo.

- **Model** — drop `yolo26x.onnx` (or any other YOLOv8/YOLO26 ONNX export with
  COCO-80 outputs) into `ObjectDetector/`. In Xcode, make sure the file is a
  member of the `ObjectDetector` target so it ends up in the app bundle —
  `CameraDetector.swift` looks it up via `Bundle.main.path(forResource:)`.
- **SDK** — drop `imaged.xcframework` at the project root next to
  `ObjectDetector.xcodeproj`. If you don't have an SDK build, see
  [imaged.dev](https://imaged.dev).

## Run

Open `ObjectDetector.xcodeproj` in Xcode, pick the `ObjectDetector` scheme
with the `My Mac` destination, and run. macOS will prompt for camera
permission on first launch.
