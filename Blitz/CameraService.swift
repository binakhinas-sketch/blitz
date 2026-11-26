import AVFoundation
import UIKit
import SwiftUI

final class CameraService: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var input: AVCaptureDeviceInput?
    private let queue = DispatchQueue(label: "blitz.camera.session")
    private var configured = false
    private var completion: ((UIImage?) -> Void)?

    @Published var position: AVCaptureDevice.Position = .back
    @Published var flashOn = false
    @Published var denied = false

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { ok in
                DispatchQueue.main.async {
                    self.denied = !ok
                    if ok { self.configureAndRun() }
                }
            }
        default:
            denied = true
        }
    }

    func stop() {
        queue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    private func configureAndRun() {
        let pos = position
        queue.async {
            if !self.configured {
                self.session.beginConfiguration()
                self.session.sessionPreset = .photo
                self.setInput(for: pos)
                if self.session.canAddOutput(self.output) { self.session.addOutput(self.output) }
                self.session.commitConfiguration()
                self.configured = true
            }
            if !self.session.isRunning { self.session.startRunning() }
        }
    }

    /// Muss auf `queue` laufen.
    private func setInput(for pos: AVCaptureDevice.Position) {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: pos),
              let newInput = try? AVCaptureDeviceInput(device: device) else { return }
        if let old = input { session.removeInput(old) }
        if session.canAddInput(newInput) {
            session.addInput(newInput)
            input = newInput
        } else if let old = input, session.canAddInput(old) {
            session.addInput(old)
        }
    }

    func flip() {
        let newPos: AVCaptureDevice.Position = position == .back ? .front : .back
        position = newPos
        queue.async {
            self.session.beginConfiguration()
            self.setInput(for: newPos)
            self.session.commitConfiguration()
        }
    }

    func setZoom(_ factor: CGFloat) {
        queue.async {
            guard let device = self.input?.device else { return }
            do {
                try device.lockForConfiguration()
                let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 8)
                device.videoZoomFactor = max(1, min(factor, maxZoom))
                device.unlockForConfiguration()
            } catch { }
        }
    }

    func capture(_ done: @escaping (UIImage?) -> Void) {
        let flash = flashOn
        let pos = position
        queue.async {
            guard let conn = self.output.connection(with: .video), conn.isEnabled, conn.isActive else {
                DispatchQueue.main.async { done(nil) }
                return
            }
            if conn.isVideoOrientationSupported { conn.videoOrientation = .portrait }
            if conn.isVideoMirroringSupported {
                conn.automaticallyAdjustsVideoMirroring = false
                conn.isVideoMirrored = (pos == .front)
            }
            let settings = AVCapturePhotoSettings()
            if self.output.supportedFlashModes.contains(.on) {
                settings.flashMode = flash ? .on : .off
            }
            self.completion = done
            self.output.capturePhoto(with: settings, delegate: self)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let img = photo.fileDataRepresentation().flatMap { UIImage(data: $0) }
        let done = completion
        completion = nil
        DispatchQueue.main.async { done?(img) }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer {
            // swiftlint:disable:next force_cast
            layer as! AVCaptureVideoPreviewLayer
        }
    }

    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.backgroundColor = .black
        v.previewLayer.session = session
        v.previewLayer.videoGravity = .resizeAspectFill
        return v
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}
