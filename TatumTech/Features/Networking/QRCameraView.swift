import AVFoundation
import SwiftUI
import UIKit

/// Live back-camera preview that reports QR code text while `isArmed` is true.
struct QRCameraView: UIViewControllerRepresentable {
    var isArmed: Bool
    let onCode: (String) -> Void
    let onFailure: () -> Void

    func makeUIViewController(context: Context) -> QRCameraViewController {
        let controller = QRCameraViewController()
        controller.onCode = onCode
        controller.onFailure = onFailure
        controller.isArmed = isArmed
        return controller
    }

    func updateUIViewController(_ controller: QRCameraViewController, context: Context) {
        controller.onCode = onCode
        controller.onFailure = onFailure
        controller.isArmed = isArmed
    }

    static func dismantleUIViewController(_ controller: QRCameraViewController, coordinator: ()) {
        controller.stop()
    }
}

final class QRCameraViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?
    var onFailure: (() -> Void)?
    var isArmed = true

    /// Start/stop block, so they run on a private queue; the box lets the session cross to it.
    private final class SessionBox: @unchecked Sendable {
        let session = AVCaptureSession()
    }

    private let box = SessionBox()
    private var session: AVCaptureSession { box.session }
    private let sessionQueue = DispatchQueue(label: "com.tatumgames.tatumtech.qr-camera")
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        guard configureSession() else {
            onFailure?()
            return
        }
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        previewLayer = layer
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let box = box
        sessionQueue.async {
            if !box.session.isRunning && !box.session.inputs.isEmpty { box.session.startRunning() }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stop()
    }

    func stop() {
        let box = box
        sessionQueue.async { if box.session.isRunning { box.session.stopRunning() } }
    }

    private func configureSession() -> Bool {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else { return false }
        session.beginConfiguration()
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            return false
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = output.availableMetadataObjectTypes.contains(.qr) ? [.qr] : []
        session.commitConfiguration()
        return true
    }

    nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        let text = metadataObjects.lazy
            .compactMap { $0 as? AVMetadataMachineReadableCodeObject }
            .first { $0.type == .qr }?
            .stringValue
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        MainActor.assumeIsolated {
            guard isArmed else { return }
            isArmed = false
            onCode?(text)
        }
    }
}
