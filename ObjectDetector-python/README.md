# Object Detector — Python

Live-camera YOLO object detection with the imaged SDK and OpenCV.
Mirrors the macOS Xcode example ([`../ObjectDetector/`](../ObjectDetector/))
but uses Python + `cv2.VideoCapture` instead of Swift + AVFoundation.

```
$ python detect.py
imaged SDK version: 0.10.0
running on coreml; press q to quit
```

A window opens with the webcam feed; detected objects are drawn as
green bounding boxes with their class label and confidence score.
Press `q` in the window to quit.

## Layout

```
ObjectDetector-python/
├── detect.py              # the runnable example
├── README.md              # this file
├── yolo26x.onnx           # YOLO26x model — you provide this (see below)
└── imaged/
    ├── __init__.py        # ctypes bindings for the SDK
    └── libsdk.dylib       # native library — you provide this (see below)
```

## Get the model and SDK

Neither file is checked into this repo (both are large binaries).

- **Model** — download `yolo26x.onnx` (or any YOLOv8/YOLO26 export with
  COCO-80 outputs) and drop it next to `detect.py`. Any other path works
  too, just pass `--model /path/to/model.onnx`.
- **SDK** — copy `libsdk.dylib` from your imaged SDK build into
  `imaged/libsdk.dylib`:

  ```bash
  cp /path/to/imaged_sdk/build/libsdk.dylib imaged/
  ```

  If you don't have an SDK build, see [imaged.dev](https://imaged.dev).

## Prerequisites

| | |
| --- | --- |
| **Python** | 3.10 or later. |
| **macOS** | Sonoma (14.0) or later, Apple Silicon (the bundled `libsdk.dylib` is universal arm64+x86_64 so Intel works too). |
| **OpenCV** | `pip install opencv-python` (~46 MB wheel). |
| **Webcam** | Any built-in or USB camera that macOS recognizes. The first time `detect.py` runs, macOS will prompt for camera permission. |
| **YOLO model** | `yolo26x.onnx` (or another COCO-80 ONNX export) placed next to `detect.py`. See above. |
| **License token (JWT)** | A test token good through 2027-04-21 is hardcoded in `detect.py` — same one used by the Xcode example. Replace with your own when you mint one. |

## Run it

```bash
cd ObjectDetector-python
pip install opencv-python              # one-time dep
python detect.py
```

If your machine has multiple webcams or you want to use an external
camera, pass `--camera N` (default `0`).

To force CPU inference (useful for comparing against CoreML latency,
or as a fallback if CoreML compilation fails for your model):

```bash
python detect.py --provider cpu
```

To raise the confidence threshold so only high-confidence detections
appear (default `0.35`):

```bash
python detect.py --threshold 0.6
```

## What the code does

`detect.py` is ~120 lines, all imperative. The flow:

1. **`AI()`** instantiates the SDK handle. ctypes loads
   `imaged/libsdk.dylib` (it's self-contained — ONNX Runtime is
   statically linked in) and the SDK initializes.

2. **License setup**: `cfg.set("license", LICENSE_TOKEN)` writes the
   JWT into config; `cfg.check_license()` verifies it offline against
   the EC public key embedded at SDK build time. No network calls.

3. **YOLO config** — five keys, all under `yolo.*`:
   - `yolo.model` — path to the ONNX file (`yolo26x.onnx` next to the
     script).
   - `yolo.classNames` — comma-separated COCO-80 labels in the model's
     output channel order.
   - `yolo.confidenceThreshold` — float in `[0, 1]`, default `0.35`.
   - `yolo.inference.provider` — `cpu`, `xnnpack`, or `coreml`.

4. **`cv2.VideoCapture(0)`** opens the default webcam. `cap.read()`
   yields BGR uint8 numpy arrays per frame.

5. **Per-frame loop**:
   ```python
   img.set_data(frame.tobytes(), w, h, ColorCode.BGR)
   detections = ai.detect("yolo", img)
   draw_detections(frame, detections)
   cv2.imshow(...)
   ```

   The `Image` instance is reused across frames — only the underlying
   pixel buffer gets replaced via `set_data`, no per-frame allocation
   on the SDK side.

6. **`ai.detect("yolo", img)`** returns a list of detection dicts:
   ```python
   [{"label": "person", "id": 0, "score": 0.92,
     "box": {"x": 312, "y": 154, "width": 88, "height": 224}}, ...]
   ```

   No tensor manipulation, no preprocessing, no NMS — that's all
   behind `detect()`.

7. The HUD shows current provider, smoothed FPS, and detection count.

## Generating your own license token

The token in `detect.py` is for trying things out. Real customers
get their own tokens minted against the SDK's license-issuance
private key. From the SDK repo:

```bash
cd /path/to/imaged_sdk
KEY=$(python src/scripts/generate_token.py mkgen)
python src/scripts/generate_token.py token \
    --private-key ec_private_key.pem \
    --model-key "$KEY" \
    --subject test@yourdomain.dev \
    --months 12
```

Replace `LICENSE_TOKEN` in `detect.py` with the printed JWT.

The full licensing reference (threat model, key custody, encrypted
models) is at [`imaged_sdk/docs/license.md`](https://example.com/license.md).

## Other families

The same `import imaged` package exposes every family, not just YOLO.
Some examples:

```python
# Background removal — mutates the image in place.
cfg.set("rembg.model", "u2net.onnx")
cfg.set("rembg.inference.provider", "coreml")
ai.process("background_removal", img)
img.save("output.png")

# Image embeddings (SigLIP / CLIP).
cfg.set("siglip2_image_embedder.model", "siglip2-vision.onnx")
features = ai.embed_image("siglip", img)   # list[float], 768 dims

# OCR.
cfg.set("paddleocr.detection.model", "det.onnx")
cfg.set("paddleocr.recognition.model", "rec.onnx")
cfg.set("paddleocr.recognition.dict",  "ppocr_keys_v1.txt")
result = ai.process("paddleocr", img)
```

Family registry includes: `yolo`, `face_detection`, `face_embedding`,
`face_attributes`, `antispoof`, `siglip`, `clip`, `reid`, `depth`,
`semantic_segmentation`, `sam`, `fastsam`, `paddleocr`, `pp_structure`,
`background_removal`, `colorization`, `deblur`, `frame_interpolation`,
`upscale`, `content_moderation`, `tracking`, `yolop`, `classifier`.

For the full Python surface, read [`imaged/__init__.py`](imaged/__init__.py)
— the `class AI:` docstring at the top summarizes the registry.

## Troubleshooting

### `ModuleNotFoundError: No module named 'imaged'`

Run from the `ObjectDetector-python/` directory, or pass the path on
`PYTHONPATH`:

```bash
PYTHONPATH=/path/to/ObjectDetector-python python detect.py
```

### `RuntimeError: Could not find libsdk`

The native library is missing. Confirm `imaged/libsdk.dylib` exists:

```bash
ls -lh imaged/libsdk.dylib
```

If it's gone, copy it back from your SDK build:

```bash
cp /path/to/imaged_sdk/build/libsdk.dylib imaged/
```

### `could not open camera index 0`

macOS hasn't granted camera permission, or another process is
holding the camera. Open **System Settings → Privacy & Security →
Camera** and enable access for whatever's hosting your Python (your
terminal, VS Code, etc.). The first run usually prompts; if you
denied it, you have to grant it manually.

If the prompt didn't appear at all, pass `--camera 1` to try the next
device — built-in webcams aren't always at index 0 on macs with
external cameras attached.

### `license verification failed`

The token in `detect.py` was edited or your SDK build embeds a
different EC public key than the one this token was signed with. Mint
a fresh token (see [generating your own license token](#generating-your-own-license-token)).

### Detections look wrong (boxes in wrong places, weird labels)

Class-name list / model output mismatch. The bundled `yolo26x.onnx`
emits COCO-80 in the standard order; `COCO_LABELS` in `detect.py`
matches that. If you swap to a custom-trained model, replace
`COCO_LABELS` with your training class list.

If the model file is corrupt or the wrong format, you'll see
`detect failed: ... ORT rejected ...` from the C++ side instead.

### Low FPS / CoreML compilation fails

CoreML is fast for CNN-style detectors like YOLO26x, but ORT's CoreML
path occasionally fails to compile specific exports. If you see a
fall-back-to-CPU warning at startup, or detection takes forever, run
with `--provider cpu` to confirm. CPU on Apple Silicon for YOLO26x
is ~50 ms/frame, which is real-time enough for most use cases.
