import AVFoundation
import SwiftUI
import TatumTechKit

/// Scans contact card QR codes (vCard or Tatum Tech format) and opens the preview.
/// After an invalid or unsupported code, scanning resumes once the message has been shown.
struct ScannerView: View {
    /// Opened from Upcoming Events: going back returns there.
    let returnsToUpcomingEvents: Bool

    @Environment(AppModel.self) private var app
    @Environment(AppRouter.self) private var router
    @State private var permission: CameraPermission = .undetermined
    @State private var isArmed = true
    @State private var cameraFailed = false
    @State private var toast: ToastMessage?
    @State private var successTrigger = 0

    private enum CameraPermission { case undetermined, granted, denied }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch permission {
            case .undetermined:
                ProgressView().tint(.white)
            case .denied:
                message("Camera permission required")
            case .granted:
                if cameraFailed {
                    message("Camera is unavailable on this device")
                } else {
                    QRCameraView(isArmed: isArmed, onCode: handle, onFailure: { cameraFailed = true })
                        .ignoresSafeArea()
                        .accessibilityLabel("Camera viewfinder")
                        .accessibilityHint("Point the camera at a contact card QR code")
                }
            }
        }
        .navigationTitle("Scanner")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationBarBackButtonHidden(returnsToUpcomingEvents)
        .toolbar {
            if returnsToUpcomingEvents {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        router.pop(to: .upcomingEvents)
                    } label: {
                        Image(systemName: "chevron.backward")
                    }
                    .accessibilityLabel("Back")
                }
            }
        }
        .sensoryFeedback(.success, trigger: successTrigger)
        .toast($toast)
        .task { await requestPermission() }
        .onAppear { isArmed = true }
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(Spacing.xl)
    }

    private func requestPermission() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permission = .granted
        case .notDetermined:
            permission = await AVCaptureDevice.requestAccess(for: .video) ? .granted : .denied
        default:
            permission = .denied
        }
    }

    private func handle(_ raw: String) {
        isArmed = false
        switch ContactCardQRCodec.parseIncoming(raw) {
        case let .success(payload):
            successTrigger += 1
            app.analytics.log(.scanContactCard)
            router.showScannedCard(payload)
        case .unsupportedVersion:
            rearm(after: "This contact card QR version is not supported")
        case .invalid:
            let local = app.local
            Task { await local.addTimelineEntry(.qrScan, description: "Scanned QR code") }
            rearm(after: "This QR code is not a valid Tatum Tech contact card")
        }
    }

    private func rearm(after text: String) {
        toast = ToastMessage(text: text)
        Task {
            try? await Task.sleep(for: .seconds(3))
            isArmed = true
        }
    }
}
