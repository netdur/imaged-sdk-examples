//
//  ContentView.swift
//  ObjectDetector
//

import AVFoundation
import SwiftUI
import imaged

private let license = "eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJpbWFnZWQuZGV2IiwiYXVkIjoic2RrLmltYWdlZC5kZXYiLCJzdWIiOiJjdXN0b21lckBpbWFnZWQuZGV2IiwiaWF0IjoxNzc3MjE1NDA5LCJuYmYiOjE3NzcyMTU0MDksImV4cCI6MTgwODMxOTQwOSwibWsiOiJiNjM5Y2RhZmYyNWEwNTcyYWFiYTY2NDg0Njg3MmI3NWZjODI3OTBkNzVhN2Y0MzE5ODg3MmVkMzExOWZmMjM4In0.1wT2igaHIAUrvUM_vNO3M6zifEgMSzp22OCxo0UCCnFoIFfCeuA1od-C_8vwQ6EiBwytaKFiRluFfHYAQLBg6Q"

struct ContentView: View {
    @State private var detector = CameraDetector(license: license)

    var body: some View {
        ZStack {
            CameraPreview(session: detector.session)

            GeometryReader { geo in
                let displayRect = aspectFit(content: detector.frameSize,
                                            in: geo.size)
                ForEach(detector.detections) { det in
                    let r = scale(det.rect,
                                  from: detector.frameSize,
                                  to: displayRect)
                    boundingBox(for: det, at: r)
                }
            }
            .allowsHitTesting(false)

            VStack {
                Spacer()
                Text(detector.status)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.6))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .padding(.bottom, 12)
            }
        }
        .frame(minWidth: 640, minHeight: 480)
        .background(.black)
    }

    @ViewBuilder
    private func boundingBox(for det: Detection, at rect: CGRect) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .stroke(.green, lineWidth: 2)
                .frame(width: rect.width, height: rect.height)
            Text("\(det.label) \(Int(det.score * 100))%")
                .font(.caption2.bold())
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(.green)
                .foregroundStyle(.black)
                .offset(y: -16)
        }
        .position(x: rect.midX, y: rect.midY)
    }
}

private func aspectFit(content: CGSize, in container: CGSize) -> CGRect {
    guard content.width > 0, content.height > 0 else {
        return CGRect(origin: .zero, size: container)
    }
    let scale = min(container.width / content.width,
                    container.height / content.height)
    let w = content.width * scale
    let h = content.height * scale
    return CGRect(x: (container.width - w) / 2,
                  y: (container.height - h) / 2,
                  width: w, height: h)
}

private func scale(_ rect: CGRect, from frame: CGSize, to display: CGRect) -> CGRect {
    guard frame.width > 0, frame.height > 0 else { return .zero }
    let sx = display.width / frame.width
    let sy = display.height / frame.height
    return CGRect(x: display.origin.x + rect.origin.x * sx,
                  y: display.origin.y + rect.origin.y * sy,
                  width: rect.width * sx,
                  height: rect.height * sy)
}

struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.previewLayer.session = session
        v.previewLayer.videoGravity = .resizeAspect
        if let conn = v.previewLayer.connection {
            conn.automaticallyAdjustsVideoMirroring = false
            conn.isVideoMirrored = false
        }
        return v
    }

    func updateNSView(_ nsView: PreviewView, context: Context) {}

    final class PreviewView: NSView {
        let previewLayer = AVCaptureVideoPreviewLayer()

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            layer = CALayer()
            layer?.backgroundColor = NSColor.black.cgColor
            layer?.addSublayer(previewLayer)
        }

        required init?(coder: NSCoder) { fatalError() }

        override func layout() {
            super.layout()
            previewLayer.frame = bounds
        }
    }
}

#Preview {
    ContentView()
}
