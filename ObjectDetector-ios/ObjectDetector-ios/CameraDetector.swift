import AVFoundation
import CoreVideo
import Foundation
import UIKit
import imaged

struct Detection: Sendable, Identifiable {
    let id = UUID()
    let label: String
    let score: Double
    /// Bounding box in pixel coords of the buffer the SDK saw. The
    /// rotation coordinator delivers buffers already at horizon level,
    /// so width/height here is the rotated-buffer's width/height.
    let rect: CGRect
}

@MainActor
@Observable
final class CameraDetector {
    var detections: [Detection] = []
    /// Buffer size *as the SDK sees it* — already rotated to horizon
    /// level by `AVCaptureDeviceRotationCoordinator`. The overlay
    /// in ContentView aspect-fits this into the preview rect.
    var frameSize: CGSize = .zero
    var status: String = "Initializing…"
    /// Currently active camera. Toggle via `switchCamera()`.
    var cameraPosition: AVCaptureDevice.Position = .back
    let session = AVCaptureSession()

    private let pipeline: DetectionPipeline
    private var videoOutput: AVCaptureVideoDataOutput?
    private var dataOutputConnection: AVCaptureConnection?
    private var currentDevice: AVCaptureDevice?

    /// Set by `CameraPreview.makeUIView` when the preview layer exists.
    /// We hold it so `AVCaptureDeviceRotationCoordinator` can drive both
    /// the capture-side rotation (data output → SDK) and the preview-side
    /// rotation (what the user sees) from one source of truth.
    private weak var previewLayer: AVCaptureVideoPreviewLayer?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var captureRotationObservation: NSKeyValueObservation?
    private var previewRotationObservation: NSKeyValueObservation?

    init(license: String) {
        let pipeline = DetectionPipeline(license: license)
        self.pipeline = pipeline
        pipeline.onStatus = { [weak self] s in
            Task { @MainActor in self?.status = s }
        }
        pipeline.onResult = { [weak self] detections, size in
            Task { @MainActor in
                self?.detections = detections
                self?.frameSize = size
            }
        }
        Task { await start() }
    }

    private func start() async {
        guard pipeline.isReady else { return }
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        guard granted else {
            status = "Camera access denied. Enable it in Settings → Privacy → Camera."
            return
        }
        configureSession()
    }

    /// Toggle between back and front cameras. Reuses the existing video
    /// output (so its sample buffer delegate stays attached) and just
    /// swaps the input — then re-creates the rotation coordinator with
    /// the new device.
    func switchCamera() {
        cameraPosition = (cameraPosition == .back) ? .front : .back
        applyCameraInput()
    }

    /// Called by CameraPreview when its layer is created. Stores the
    /// preview layer ref and (re-)installs the rotation coordinator.
    func attachPreviewLayer(_ layer: AVCaptureVideoPreviewLayer) {
        layer.session = session
        layer.videoGravity = .resizeAspect
        previewLayer = layer
        installRotationCoordinator()
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .hd1280x720

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(pipeline, queue: pipeline.queue)
        guard session.canAddOutput(output) else {
            status = "Cannot attach video output."
            session.commitConfiguration()
            return
        }
        session.addOutput(output)
        videoOutput = output
        dataOutputConnection = output.connection(with: .video)

        session.commitConfiguration()

        applyCameraInput()

        let session = self.session
        Task.detached(priority: .userInitiated) {
            session.startRunning()
        }
        status = "Running — point the camera at something."
    }

    private func applyCameraInput() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        for input in session.inputs {
            if let dev = (input as? AVCaptureDeviceInput)?.device, dev.hasMediaType(.video) {
                session.removeInput(input)
            }
        }

        let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                             for: .video,
                                             position: cameraPosition)
            ?? AVCaptureDevice.default(for: .video)
        guard let device else {
            status = "No \(cameraPosition == .front ? "front" : "back") camera found."
            return
        }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                status = "Cannot attach camera input."
                return
            }
            session.addInput(input)
        } catch {
            status = "Camera input error: \(error.localizedDescription)"
            return
        }
        currentDevice = device

        // The data-output connection is recreated when the input
        // changes; refresh our reference.
        dataOutputConnection = videoOutput?.connection(with: .video)

        // Front camera: mirror the data output so detection coords match
        // the auto-mirrored preview. Back camera: never mirror.
        if let conn = dataOutputConnection, conn.isVideoMirroringSupported {
            conn.automaticallyAdjustsVideoMirroring = false
            conn.isVideoMirrored = (cameraPosition == .front)
        }

        // The rotation coordinator is per-(device, previewLayer); recreate
        // when either changes.
        installRotationCoordinator()
    }

    /// Wire `AVCaptureDeviceRotationCoordinator` to both the data-output
    /// and preview connections. The coordinator publishes per-camera
    /// horizon-level angles via KVO, so we don't have to hand-roll an
    /// interface→angle mapping (which gets the iPad and front-camera cases
    /// wrong because their sensor mounts differ from iPhone back-camera).
    private func installRotationCoordinator() {
        captureRotationObservation = nil
        previewRotationObservation = nil

        guard let device = currentDevice else { return }
        let coordinator = AVCaptureDevice.RotationCoordinator(
            device: device,
            previewLayer: previewLayer
        )
        rotationCoordinator = coordinator

        applyCaptureRotation()
        applyPreviewRotation()

        captureRotationObservation = coordinator.observe(
            \.videoRotationAngleForHorizonLevelCapture,
             options: [.new]
        ) { [weak self] _, _ in
            Task { @MainActor in self?.applyCaptureRotation() }
        }
        previewRotationObservation = coordinator.observe(
            \.videoRotationAngleForHorizonLevelPreview,
             options: [.new]
        ) { [weak self] _, _ in
            Task { @MainActor in self?.applyPreviewRotation() }
        }
    }

    private func applyCaptureRotation() {
        guard let conn = dataOutputConnection,
              let angle = rotationCoordinator?.videoRotationAngleForHorizonLevelCapture
        else { return }
        if conn.isVideoRotationAngleSupported(angle) {
            conn.videoRotationAngle = angle
        }
    }

    private func applyPreviewRotation() {
        guard let conn = previewLayer?.connection,
              let angle = rotationCoordinator?.videoRotationAngleForHorizonLevelPreview
        else { return }
        if conn.isVideoRotationAngleSupported(angle) {
            conn.videoRotationAngle = angle
        }
    }
}

// COCO 80 classes — standard YOLOv8/YOLO11/YOLOv26 training set.
let cocoLabels: [String] = [
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
    "hair drier", "toothbrush"
]

// All SDK calls live here, on a single background queue. The class is
// `@unchecked Sendable` because its mutable state (inFlight flag, scratch
// buffer) is only ever touched from `queue`.
final class DetectionPipeline: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let queue = DispatchQueue(label: "imaged.detection", qos: .userInitiated)
    var onStatus: (@Sendable (String) -> Void)?
    var onResult: (@Sendable ([Detection], CGSize) -> Void)?
    private(set) var isReady = false

    private let ai = AISDK()
    private var inFlight = false
    private var scratch: UnsafeMutablePointer<UInt8>?
    private var scratchCapacity = 0

    init(license: String) {
        super.init()
        configureSDK(license: license)
    }

    deinit {
        scratch?.deallocate()
    }

    private func configureSDK(license: String) {
        let cfg = ai.options
        cfg.setOption(forKey: "license", stringValue: license)
        let result = cfg.checkLicense()
        guard result == .success, ai.isLicensed else {
            onStatus?("License invalid (status \(result.rawValue)).")
            return
        }
        guard let modelPath = Bundle.main.path(forResource: "yolo26x", ofType: "onnx") else {
            onStatus?("yolo26x.onnx not in app bundle. Check target membership in Xcode.")
            return
        }
        cfg.setOption(forKey: "yolo.model", stringValue: modelPath)
        cfg.setOption(forKey: "yolo.classNames", stringValue: cocoLabels.joined(separator: ","))
        cfg.setOption(forKey: "yolo.confidenceThreshold", doubleValue: 0.35)
        cfg.setOption(forKey: "yolo.inference.provider", stringValue: "coreml")
        guard ai.hasFamily("yolo") else {
            onStatus?("yolo family unavailable in this SDK build.")
            return
        }
        isReady = true
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard isReady, !inFlight,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        inFlight = true
        defer { inFlight = false }
        process(pixelBuffer)
    }

    private func process(_ cv: CVPixelBuffer) {
        let width = CVPixelBufferGetWidth(cv)
        let height = CVPixelBufferGetHeight(cv)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(cv)
        let rowBytes = width * 4
        let needed = rowBytes * height

        if scratchCapacity < needed {
            scratch?.deallocate()
            scratch = UnsafeMutablePointer<UInt8>.allocate(capacity: needed)
            scratchCapacity = needed
        }
        guard let dst = scratch else { return }

        CVPixelBufferLockBaseAddress(cv, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(cv, .readOnly) }
        guard let src = CVPixelBufferGetBaseAddress(cv) else { return }

        if bytesPerRow == rowBytes {
            memcpy(dst, src, needed)
        } else {
            for y in 0..<height {
                memcpy(dst.advanced(by: y * rowBytes),
                       src.advanced(by: y * bytesPerRow),
                       rowBytes)
            }
        }

        let img = AIImage()
        img.setData(dst, width: Int32(width), height: Int32(height), colorCode: .BGRA)

        let response = ai.detect("yolo", in: img)
        guard response.error == 0 else { return }

        let dets: [Detection] = (response.objects ?? []).map { obj in
            Detection(
                label: obj.label ?? "?",
                score: obj.score,
                rect: CGRect(x: CGFloat(obj.boundingBox.x),
                             y: CGFloat(obj.boundingBox.y),
                             width: CGFloat(obj.boundingBox.width),
                             height: CGFloat(obj.boundingBox.height))
            )
        }
        onResult?(dets, CGSize(width: width, height: height))
    }
}
