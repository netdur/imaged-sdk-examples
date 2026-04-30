"""imaged SDK - AI-powered image processing.

v0.10.0 family-registry API. The legacy `ModelType` enum and per-capability
methods (`upscale`, `colorize`, `yolov8`, ...) were removed in v0.10.0 — see
CHANGELOG. Dispatch is now string-keyed by family id:

    ai = AI()
    ai.config.load()                          # reads options.json + license
    if ai.family_exists("yolo"):
        for d in ai.detect("yolo", image):    # detection family
            print(d["label"], d["score"])
    ai.process("upscale", image)              # image-to-image family (mutates)
    feats = ai.embed_image("siglip", image)   # embedding family

Family ids: antispoof, background_removal, classifier, clip, colorization,
content_moderation, deblur, depth, face_attributes, face_detection,
face_embedding, fastsam, frame_interpolation, paddleocr, reid, sam,
semantic_segmentation, siglip, tracking, upscale, yolo, yolop.
"""

import ctypes
import platform
from ctypes import (POINTER, Structure, c_char_p, c_double, c_float, c_int,
                    c_int64, c_long, c_ubyte, c_uint, c_void_p)
from enum import IntEnum
from pathlib import Path


def _find_library():
    pkg_dir = Path(__file__).parent
    libname = "libsdk.dylib" if platform.system() == "Darwin" else "libsdk.so"
    candidates = [pkg_dir / libname, Path(libname), Path("build") / libname]
    for path in candidates:
        if path.exists():
            return ctypes.CDLL(str(path))
    raise RuntimeError(f"Could not find {libname}. Searched: {[str(c) for c in candidates]}")


_lib = _find_library()

AIHandle = c_void_p
ConfigurationOptionsHandle = c_void_p
ImageHandle = c_void_p


class ColorCode(IntEnum):
    BGR = 0
    RGB = 1
    BGRA = 2
    RGBA = 3
    GRAY = 4
    YUV_I420 = 5
    YUV_NV12 = 6


class _Response(Structure):
    _fields_ = [("score", c_double), ("error", c_int), ("message", c_char_p)]


class _ResponseFeatures(Structure):
    _fields_ = [("error", c_int), ("message", c_char_p),
                ("features", POINTER(c_float)), ("size", c_int), ("score", c_double)]


class _Rect(Structure):
    _fields_ = [("x", c_int), ("y", c_int), ("width", c_int), ("height", c_int)]


class _Object(Structure):
    _fields_ = [("label", c_char_p), ("id", c_int), ("score", c_double), ("boundingBox", _Rect)]


class _ResponseObject(Structure):
    _fields_ = [("error", c_int), ("message", c_char_p),
                ("objects", POINTER(_Object)), ("objectCount", c_int)]


class _TrackedObject(Structure):
    _fields_ = [("trackId", c_int), ("label", c_char_p), ("classId", c_int),
                ("score", c_float), ("boundingBox", _Rect)]


class _TrackedResult(Structure):
    _fields_ = [("objects", POINTER(_TrackedObject)), ("objectCount", c_int)]


def _s(text):
    return ctypes.create_string_buffer(text.encode("utf-8"))


def _obj_to_dict(obj):
    return {
        "label": obj.label.decode("utf-8") if obj.label else "",
        "id": obj.id,
        "score": obj.score,
        "box": {"x": obj.boundingBox.x, "y": obj.boundingBox.y,
                "width": obj.boundingBox.width, "height": obj.boundingBox.height},
    }


# AI handle + lifecycle
_lib.ai_create.restype = AIHandle
_lib.ai_destroy.argtypes = [AIHandle]
_lib.ai_get_options.argtypes = [AIHandle]; _lib.ai_get_options.restype = ConfigurationOptionsHandle
_lib.ai_get_version.argtypes = [AIHandle]; _lib.ai_get_version.restype = c_char_p
_lib.ai_is_licensed.argtypes = [AIHandle]; _lib.ai_is_licensed.restype = c_int
_lib.ai_get_expiration_date.argtypes = [AIHandle]; _lib.ai_get_expiration_date.restype = c_int64
_lib.ai_similarity.argtypes = [AIHandle, _ResponseFeatures, _ResponseFeatures]; _lib.ai_similarity.restype = c_double
_lib.ai_softmax.argtypes = [AIHandle, POINTER(c_float), c_int, POINTER(c_int)]; _lib.ai_softmax.restype = POINTER(c_float)

# Family registry (v0.10.0)
_lib.ai_family_exists.argtypes = [AIHandle, c_char_p]; _lib.ai_family_exists.restype = c_int
_lib.ai_family_detect.argtypes = [AIHandle, c_char_p, ImageHandle]; _lib.ai_family_detect.restype = _ResponseObject
_lib.ai_family_embed_image.argtypes = [AIHandle, c_char_p, ImageHandle]; _lib.ai_family_embed_image.restype = _ResponseFeatures
_lib.ai_family_embed_text.argtypes = [AIHandle, c_char_p, c_char_p]; _lib.ai_family_embed_text.restype = _ResponseFeatures
_lib.ai_family_process.argtypes = [AIHandle, c_char_p, ImageHandle]; _lib.ai_family_process.restype = _Response

# Configuration
_lib.configuration_options_get_instance.restype = ConfigurationOptionsHandle
_lib.configuration_options_load_options.argtypes = [ConfigurationOptionsHandle]
_lib.configuration_options_load_options_file.argtypes = [ConfigurationOptionsHandle, c_char_p]
_lib.configuration_options_load_options_file.restype = c_int
_lib.configuration_options_set_string.argtypes = [ConfigurationOptionsHandle, c_char_p, c_char_p]
_lib.configuration_options_get_string.argtypes = [ConfigurationOptionsHandle, c_char_p]
_lib.configuration_options_get_string.restype = c_char_p
_lib.configuration_options_check_license.argtypes = [ConfigurationOptionsHandle]
_lib.configuration_options_check_license.restype = c_int

# Image
_lib.image_create.restype = ImageHandle
_lib.image_destroy.argtypes = [ImageHandle]
_lib.image_load.argtypes = [ImageHandle, c_char_p]; _lib.image_load.restype = c_int
_lib.image_save.argtypes = [ImageHandle, c_char_p]; _lib.image_save.restype = c_int
_lib.image_get_width.argtypes = [ImageHandle]; _lib.image_get_width.restype = c_int
_lib.image_get_height.argtypes = [ImageHandle]; _lib.image_get_height.restype = c_int
_lib.image_get_channels.argtypes = [ImageHandle]; _lib.image_get_channels.restype = c_int
_lib.image_is_empty.argtypes = [ImageHandle]; _lib.image_is_empty.restype = c_int
_lib.image_resize.argtypes = [ImageHandle, c_uint, c_uint]
_lib.image_rotate.argtypes = [ImageHandle, c_int]
_lib.image_set_data.argtypes = [ImageHandle, POINTER(c_ubyte), c_int, c_int, c_int]
_lib.image_set_data_channels.argtypes = [ImageHandle, POINTER(c_ubyte), c_int, c_int, c_int]

# Generic Model Runner
class _GenericResultC(Structure):
    _fields_ = [("type", c_int), ("error", c_int), ("message", c_char_p),
                ("score", c_double), ("label", c_char_p),
                ("features", POINTER(c_float)), ("featuresSize", c_int),
                ("objects", POINTER(_Object)), ("objectCount", c_int)]

_lib.ai_load_generic_model.argtypes = [AIHandle, c_char_p]; _lib.ai_load_generic_model.restype = c_int
_lib.ai_unload_generic_model.argtypes = [AIHandle, c_char_p]; _lib.ai_unload_generic_model.restype = c_int
_lib.ai_run_generic_model.argtypes = [AIHandle, c_char_p, ImageHandle]; _lib.ai_run_generic_model.restype = _GenericResultC

# Tracker
TrackerHandle = c_void_p
_lib.tracker_create.argtypes = [c_int, c_int, c_float]; _lib.tracker_create.restype = TrackerHandle
_lib.tracker_destroy.argtypes = [TrackerHandle]
_lib.tracker_update.argtypes = [TrackerHandle, _ResponseObject]; _lib.tracker_update.restype = _TrackedResult
_lib.tracker_reset.argtypes = [TrackerHandle]


class Image:
    """Image container for the SDK."""

    def __init__(self):
        self._handle = _lib.image_create()

    def __del__(self):
        if self._handle:
            _lib.image_destroy(self._handle)

    @property
    def handle(self):
        return self._handle

    def load(self, path: str) -> bool:
        return bool(_lib.image_load(self._handle, _s(path)))

    def save(self, path: str) -> bool:
        return bool(_lib.image_save(self._handle, _s(path)))

    @property
    def width(self) -> int:
        return _lib.image_get_width(self._handle)

    @property
    def height(self) -> int:
        return _lib.image_get_height(self._handle)

    @property
    def channels(self) -> int:
        return _lib.image_get_channels(self._handle)

    @property
    def empty(self) -> bool:
        return bool(_lib.image_is_empty(self._handle))

    def resize(self, width: int, height: int):
        _lib.image_resize(self._handle, width, height)

    def rotate(self, degrees: int):
        _lib.image_rotate(self._handle, degrees)

    def set_data(self, data: bytes, width: int, height: int,
                 color_code: ColorCode = ColorCode.BGR):
        """Copy raw pixel bytes into the image buffer.
        `data` must be width * height * channels bytes; channels is implied
        by `color_code` (3 for BGR/RGB, 4 for BGRA/RGBA, 1 for GRAY)."""
        buf = (c_ubyte * len(data)).from_buffer_copy(data)
        _lib.image_set_data(self._handle, buf, width, height, int(color_code))

    def set_data_channels(self, data: bytes, width: int, height: int, channels: int):
        """Like set_data but takes the channel count directly. Useful when
        you have raw bytes and don't want to commit to a ColorCode."""
        buf = (c_ubyte * len(data)).from_buffer_copy(data)
        _lib.image_set_data_channels(self._handle, buf, width, height, channels)


class Config:
    """Configuration options for the SDK."""

    def __init__(self, handle):
        self._handle = handle

    def load(self):
        """Load options.json from the working directory."""
        _lib.configuration_options_load_options(self._handle)

    def load_file(self, path: str) -> int:
        return _lib.configuration_options_load_options_file(self._handle, _s(path))

    def set(self, key: str, value: str):
        _lib.configuration_options_set_string(self._handle, _s(key), _s(value))

    def get(self, key: str) -> str:
        result = _lib.configuration_options_get_string(self._handle, _s(key))
        return result.decode("utf-8") if result else ""

    def check_license(self) -> bool:
        """Reads the license token from the `license` config key, verifies it
        against the SDK's embedded EC public key, and on success unlocks the
        model decryption key. See docs/license.md."""
        return bool(_lib.configuration_options_check_license(self._handle))


class AI:
    """Main SDK interface. Family-registry API (v0.10.0)."""

    def __init__(self):
        self._handle = _lib.ai_create()
        self.config = Config(_lib.ai_get_options(self._handle))

    def __del__(self):
        if self._handle:
            _lib.ai_destroy(self._handle)

    @property
    def version(self) -> str:
        return _lib.ai_get_version(self._handle).decode("utf-8")

    @property
    def licensed(self) -> bool:
        return bool(_lib.ai_is_licensed(self._handle))

    @property
    def expiration_date(self) -> int:
        return _lib.ai_get_expiration_date(self._handle)

    # Family-registry dispatch.

    def family_exists(self, family_id: str) -> bool:
        return bool(_lib.ai_family_exists(self._handle, _s(family_id)))

    def detect(self, family_id: str, image: Image) -> list:
        """Detection family (yolo, face_detection, ...). Returns list of dicts:
        {label, id, score, box: {x, y, width, height}}."""
        result = _lib.ai_family_detect(self._handle, _s(family_id), image.handle)
        if result.error:
            msg = result.message.decode("utf-8") if result.message else "unknown error"
            raise RuntimeError(f"family_detect({family_id}): {msg}")
        return [_obj_to_dict(result.objects[i]) for i in range(result.objectCount)]

    def embed_image(self, family_id: str, image: Image) -> list:
        """Image embedding family (siglip, clip, reid, face_embedding)."""
        result = _lib.ai_family_embed_image(self._handle, _s(family_id), image.handle)
        if result.error:
            msg = result.message.decode("utf-8") if result.message else "unknown error"
            raise RuntimeError(f"family_embed_image({family_id}): {msg}")
        return [result.features[i] for i in range(result.size)]

    def embed_text(self, family_id: str, text: str) -> list:
        """Text embedding family (siglip, clip)."""
        result = _lib.ai_family_embed_text(self._handle, _s(family_id), _s(text))
        if result.error:
            msg = result.message.decode("utf-8") if result.message else "unknown error"
            raise RuntimeError(f"family_embed_text({family_id}): {msg}")
        return [result.features[i] for i in range(result.size)]

    def process(self, family_id: str, image: Image):
        """Image-to-image family (upscale, background_removal, colorization,
        deblur, content_moderation). Mutates `image` in place. Returns the raw
        Response struct (`.score`, `.error`, `.message`)."""
        return _lib.ai_family_process(self._handle, _s(family_id), image.handle)

    # Similarity / softmax helpers.

    def similarity(self, features1, features2) -> float:
        f1 = _ResponseFeatures()
        f1.features = (c_float * len(features1))(*features1)
        f1.size = len(features1)
        f2 = _ResponseFeatures()
        f2.features = (c_float * len(features2))(*features2)
        f2.size = len(features2)
        return _lib.ai_similarity(self._handle, f1, f2)

    # Generic Model Runner.

    def load_generic(self, name: str) -> bool:
        return bool(_lib.ai_load_generic_model(self._handle, _s(name)))

    def unload_generic(self, name: str) -> bool:
        return bool(_lib.ai_unload_generic_model(self._handle, _s(name)))

    def run_generic(self, name: str, image: Image) -> dict:
        """Run a generic model. Returns dict with 'type' and type-specific fields."""
        r = _lib.ai_run_generic_model(self._handle, _s(name), image.handle)
        result = {"type": ["image", "class", "embedding", "detection"][r.type], "error": r.error}
        if r.type == 1:
            result["score"] = r.score
            result["label"] = r.label.decode("utf-8") if r.label else ""
        elif r.type == 2:
            result["features"] = [r.features[i] for i in range(r.featuresSize)]
        elif r.type == 3:
            result["objects"] = [_obj_to_dict(r.objects[i]) for i in range(r.objectCount)]
        return result


class Tracker:
    """ByteTrack-based object tracker."""

    def __init__(self, max_age: int = 30, min_hits: int = 3, iou_threshold: float = 0.3):
        self._handle = _lib.tracker_create(max_age, min_hits, c_float(iou_threshold))

    def __del__(self):
        if self._handle:
            _lib.tracker_destroy(self._handle)

    def update(self, detections: list) -> list:
        """Update tracker with detections from `AI.detect(...)`. Returns
        tracked objects with persistent track_ids."""
        n = len(detections)
        c_objects = (_Object * n)()
        for i, det in enumerate(detections):
            c_objects[i].label = det["label"].encode("utf-8")
            c_objects[i].id = det["id"]
            c_objects[i].score = det["score"]
            c_objects[i].boundingBox.x = det["box"]["x"]
            c_objects[i].boundingBox.y = det["box"]["y"]
            c_objects[i].boundingBox.width = det["box"]["width"]
            c_objects[i].boundingBox.height = det["box"]["height"]

        resp = _ResponseObject()
        resp.objects = c_objects
        resp.objectCount = n

        result = _lib.tracker_update(self._handle, resp)
        tracked = []
        for i in range(result.objectCount):
            obj = result.objects[i]
            tracked.append({
                "track_id": obj.trackId,
                "label": obj.label.decode("utf-8") if obj.label else "",
                "class_id": obj.classId,
                "score": obj.score,
                "box": {"x": obj.boundingBox.x, "y": obj.boundingBox.y,
                        "width": obj.boundingBox.width, "height": obj.boundingBox.height},
            })
        return tracked

    def reset(self):
        _lib.tracker_reset(self._handle)
