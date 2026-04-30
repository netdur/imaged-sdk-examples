//
//  ContentView.swift
//  ObjectDetector-ios
//

import AVFoundation
import SwiftUI
import UIKit
import imaged

private let license = "eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJpbWFnZWQuZGV2IiwiYXVkIjoic2RrLmltYWdlZC5kZXYiLCJzdWIiOiJjdXN0b21lckBpbWFnZWQuZGV2IiwiaWF0IjoxNzc3MjE1NDA5LCJuYmYiOjE3NzcyMTU0MDksImV4cCI6MTgwODMxOTQwOSwibWsiOiJiNjM5Y2RhZmYyNWEwNTcyYWFiYTY2NDg0Njg3MmI3NWZjODI3OTBkNzVhN2Y0MzE5ODg3MmVkMzExOWZmMjM4In0.1wT2igaHIAUrvUM_vNO3M6zifEgMSzp22OCxo0UCCnFoIFfCeuA1od-C_8vwQ6EiBwytaKFiRluFfHYAQLBg6Q"

struct ContentView: View {
    @State private var detector = CameraDetector(license: license)

    var body: some View {
        ZStack {
            CameraPreview(detector: detector)

            // Overlay shares the preview's full-screen rect by also
            // ignoring the safe area; otherwise the GeometryReader sits
            // inside notch/home-bar insets and boxes drift relative to
            // the camera image.
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
                HStack {
                    Spacer()
                    Button {
                        detector.switchCamera()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .font(.title3)
                            .padding(10)
                            .background(.black.opacity(0.6))
                            .foregroundStyle(.white)
                            .clipShape(Circle())
                    }
                    .padding(.top, 60)
                    .padding(.trailing, 20)
                }
                Spacer()
                Text(detector.status)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.6))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .padding(.bottom, 24)
            }
        }
        .ignoresSafeArea()
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

/// Camera preview wrapper. The actual rotation work is done by
/// `AVCaptureDeviceRotationCoordinator` inside CameraDetector — this view
/// just hands its preview layer to the detector and lets the coordinator
/// drive both ends.
struct CameraPreview: UIViewRepresentable {
    let detector: CameraDetector

    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        detector.attachPreviewLayer(v.previewLayer)
        return v
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer {
            // swiftlint:disable:next force_cast
            layer as! AVCaptureVideoPreviewLayer
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .black
        }

        required init?(coder: NSCoder) { fatalError() }
    }
}

#Preview {
    ContentView()
}
