# ObjectDetector — iOS

Live-camera YOLO object detection with the imaged SDK on iOS, written in
Swift / SwiftUI / AVFoundation. Same example as
[`../ObjectDetector/`](../ObjectDetector/) but built for iPhone / iPad.

## Layout

```
ObjectDetector-ios/
├── ObjectDetector-ios.xcodeproj
├── ObjectDetector-ios/
│   ├── ObjectDetector_iosApp.swift
│   ├── ContentView.swift
│   ├── CameraDetector.swift
│   ├── Assets.xcassets
│   └── yolo26x.onnx        # YOLO model — you provide this (see below)
└── imaged.xcframework      # imaged SDK — you provide this (see below)
```

## Get the model and SDK

Neither file is checked into this repo.

- **Model** — drop `yolo26x.onnx` (or any other YOLOv8/YOLO26 ONNX export with
  COCO-80 outputs) into `ObjectDetector-ios/`. In Xcode, make sure the file
  is a member of the `ObjectDetector-ios` target so it lands in the app
  bundle — `CameraDetector.swift` looks it up via
  `Bundle.main.path(forResource:)`.
- **SDK** — drop `imaged.xcframework` at the project root next to
  `ObjectDetector-ios.xcodeproj`. If you don't have an SDK build, see
  [imaged.dev](https://imaged.dev).

## Run

Open `ObjectDetector-ios.xcodeproj` in Xcode, pick the
`ObjectDetector-ios` scheme with a real device or simulator, and run.
iOS will prompt for camera permission on first launch.
