import AVFoundation
import CoreVideo
import Foundation
import imaged

struct Detection: Sendable, Identifiable {
    let id = UUID()
    let label: String
    let score: Double
    let rect: CGRect
}

@MainActor
@Observable
final class CameraDetector {
    var detections: [Detection] = []
    var frameSize: CGSize = .zero
    var status: String = "Initializing…"
    let session = AVCaptureSession()

    private let pipeline: DetectionPipeline

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
            status = "Camera access denied. Enable it in System Settings → Privacy → Camera."
            return
        }
        configureSession()
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .vga640x480

        guard let device = AVCaptureDevice.default(for: .video) else {
            status = "No camera found."
            session.commitConfiguration()
            return
        }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                status = "Cannot attach camera input."
                session.commitConfiguration()
                return
            }
            session.addInput(input)
        } catch {
            status = "Camera input error: \(error.localizedDescription)"
            session.commitConfiguration()
            return
        }

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
        session.commitConfiguration()

        let session = self.session
        Task.detached(priority: .userInitiated) {
            session.startRunning()
        }
        status = "Running — point the camera at something."
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
