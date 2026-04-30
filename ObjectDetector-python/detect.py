#!/usr/bin/env python3
"""Live-camera YOLO object detection with the imaged SDK.

Mirrors the macOS Xcode example (../ObjectDetector/) but with OpenCV's
VideoCapture instead of AVFoundation. Each webcam frame is fed into
the SDK as a BGR buffer; detections are drawn back on the frame and
shown in a window.

Press `q` to quit.

Usage:
    python detect.py                       # default webcam, coreml provider
    python detect.py --camera 1            # second webcam
    python detect.py --provider cpu        # force CPU inference
    python detect.py --threshold 0.5       # raise confidence cutoff
"""

from __future__ import annotations

import argparse
import sys
import time
from pathlib import Path

import cv2
import numpy as np

from imaged import AI, ColorCode, Image  # type: ignore[import-not-found]

# Same license token as the Xcode ObjectDetector example.
LICENSE_TOKEN = (
    "eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9."
    "eyJpc3MiOiJpbWFnZWQuZGV2IiwiYXVkIjoic2RrLmltYWdlZC5kZXYiLCJzdWIiOiJjdXN0b21lckBpbWFnZWQu"
    "ZGV2IiwiaWF0IjoxNzc3MjE1NDA5LCJuYmYiOjE3NzcyMTU0MDksImV4cCI6MTgwODMxOTQwOSwibWsiOiJiNjM5"
    "Y2RhZmYyNWEwNTcyYWFiYTY2NDg0Njg3MmI3NWZjODI3OTBkNzVhN2Y0MzE5ODg3MmVkMzExOWZmMjM4In0."
    "1wT2igaHIAUrvUM_vNO3M6zifEgMSzp22OCxo0UCCnFoIFfCeuA1od-C_8vwQ6EiBwytaKFiRluFfHYAQLBg6Q"
)

# COCO-80 class names — matches the YOLO26x model's output channel order.
COCO_LABELS = [
    "person", "bicycle", "car", "motorcycle", "airplane", "bus", "train",
    "truck", "boat", "traffic light", "fire hydrant", "stop sign",
    "parking meter", "bench", "bird", "cat", "dog", "horse", "sheep", "cow",
    "elephant", "bear", "zebra", "giraffe", "backpack", "umbrella", "handbag",
    "tie", "suitcase", "frisbee", "skis", "snowboard", "sports ball", "kite",
    "baseball bat", "baseball glove", "skateboard", "surfboard",
    "tennis racket", "bottle", "wine glass", "cup", "fork", "knife", "spoon",
    "bowl", "banana", "apple", "sandwich", "orange", "broccoli", "carrot",
    "hot dog", "pizza", "donut", "cake", "chair", "couch", "potted plant",
    "bed", "dining table", "toilet", "tv", "laptop", "mouse", "remote",
    "keyboard", "cell phone", "microwave", "oven", "toaster", "sink",
    "refrigerator", "book", "clock", "vase", "scissors", "teddy bear",
    "hair drier", "toothbrush",
]


def configure_sdk(ai: AI, model_path: Path, provider: str, threshold: float) -> bool:
    cfg = ai.config
    cfg.set("license", LICENSE_TOKEN)
    if not cfg.check_license() or not ai.licensed:
        print("license verification failed", file=sys.stderr)
        return False

    cfg.set("yolo.model", str(model_path))
    cfg.set("yolo.classNames", ",".join(COCO_LABELS))
    cfg.set("yolo.confidenceThreshold", str(threshold))
    cfg.set("yolo.inference.provider", provider)

    if not ai.family_exists("yolo"):
        print("yolo family is not registered in this SDK build", file=sys.stderr)
        return False
    return True


def draw_detections(frame: np.ndarray, detections: list) -> None:
    """Draw boxes + labels in place on a BGR frame."""
    for det in detections:
        box = det["box"]
        x, y, w, h = box["x"], box["y"], box["width"], box["height"]
        label = f"{det['label']} {int(det['score'] * 100)}%"

        cv2.rectangle(frame, (x, y), (x + w, y + h), (0, 255, 0), 2)

        (tw, th), baseline = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, 0.5, 1)
        ly1 = max(0, y - th - baseline - 4)
        cv2.rectangle(frame, (x, ly1), (x + tw + 6, y), (0, 255, 0), -1)
        cv2.putText(frame, label, (x + 3, y - baseline - 2),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 0, 0), 1, cv2.LINE_AA)


def hud(frame: np.ndarray, *, fps: float, provider: str, count: int) -> None:
    text = f"{provider.upper()}  {fps:5.1f} fps  {count} detections"
    (tw, th), bl = cv2.getTextSize(text, cv2.FONT_HERSHEY_SIMPLEX, 0.55, 1)
    cv2.rectangle(frame, (8, 8), (8 + tw + 12, 8 + th + bl + 8), (0, 0, 0), -1)
    cv2.putText(frame, text, (14, 8 + th + 6),
                cv2.FONT_HERSHEY_SIMPLEX, 0.55, (255, 255, 255), 1, cv2.LINE_AA)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--camera", type=int, default=0,
                        help="OpenCV camera index (default: 0)")
    parser.add_argument("--model", type=Path,
                        default=Path(__file__).parent / "yolo26x.onnx",
                        help="path to YOLO ONNX model (default: ./yolo26x.onnx)")
    parser.add_argument("--provider", default="coreml",
                        choices=["cpu", "xnnpack", "coreml"],
                        help="inference provider (default: coreml)")
    parser.add_argument("--threshold", type=float, default=0.35,
                        help="confidence cutoff (default: 0.35)")
    args = parser.parse_args()

    if not args.model.is_file():
        print(f"model not found: {args.model}", file=sys.stderr)
        return 2

    ai = AI()
    print(f"imaged SDK version: {ai.version}")
    if not configure_sdk(ai, args.model, args.provider, args.threshold):
        return 1

    cap = cv2.VideoCapture(args.camera)
    if not cap.isOpened():
        print(f"could not open camera index {args.camera}", file=sys.stderr)
        return 3

    print(f"running on {args.provider}; press q to quit")

    img = Image()  # reused across frames
    last = time.perf_counter()
    fps = 0.0
    smoothing = 0.85

    while True:
        ok, frame = cap.read()
        if not ok:
            print("frame read failed", file=sys.stderr)
            break

        h, w = frame.shape[:2]
        # OpenCV gives BGR uint8; matches ColorCode.BGR. tobytes() copies
        # the array contiguously and the SDK then makes its own internal
        # copy, so the numpy buffer is free to be overwritten next iteration.
        img.set_data(frame.tobytes(), w, h, ColorCode.BGR)

        try:
            detections = ai.detect("yolo", img)
        except RuntimeError as e:
            print(f"detect failed: {e}", file=sys.stderr)
            break

        draw_detections(frame, detections)

        now = time.perf_counter()
        instant_fps = 1.0 / max(now - last, 1e-6)
        last = now
        fps = smoothing * fps + (1 - smoothing) * instant_fps if fps else instant_fps
        hud(frame, fps=fps, provider=args.provider, count=len(detections))

        cv2.imshow("imaged · object detector", frame)
        if (cv2.waitKey(1) & 0xFF) == ord("q"):
            break

    cap.release()
    cv2.destroyAllWindows()
    return 0


if __name__ == "__main__":
    sys.exit(main())
