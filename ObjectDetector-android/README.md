# ObjectDetector — Android

Live-camera YOLO object detection with the imaged SDK on Android, written in
Kotlin / Jetpack Compose / CameraX. Includes a small built-in benchmark that
measures per-frame latency on the active execution provider (CPU or QNN /
Hexagon HTP).

## Layout

```
ObjectDetector-android/
├── app/
│   ├── libs/
│   │   └── imaged.aar              # imaged SDK — you provide this (see below)
│   └── src/main/
│       ├── java/dev/imaged/examples/...
│       ├── res/...
│       └── assets/
│           └── yolo26x_qdq.onnx    # YOLO model — you provide this (see below)
└── build.gradle.kts
```

## Get the model and SDK

Neither file is checked into this repo (both are large binaries).

- **Model** — drop the ONNX file you want to run into
  `app/src/main/assets/`. The default model name is `yolo26x_qdq.onnx`,
  controlled by the `BENCH_MODEL` constant in
  [`CameraDetector.kt`](app/src/main/java/dev/imaged/examples/CameraDetector.kt).
  Any YOLOv8 / YOLO26 export with COCO-80 outputs works — see the comment
  block at the top of `CameraDetector.kt` for the variants the example was
  designed against.
- **SDK** — drop `imaged.aar` into `app/libs/`. If you don't have one,
  see [imaged.dev](https://imaged.dev).

## Build and run

```bash
./gradlew :app:assembleDebug
./gradlew :app:installDebug
```

The default execution provider is `qnn` (Qualcomm Hexagon HTP) — it requires
an arm64-v8a device with the QNN runtime. Switch to `cpu` by editing
`BENCH_PROVIDER` in `CameraDetector.kt`.
