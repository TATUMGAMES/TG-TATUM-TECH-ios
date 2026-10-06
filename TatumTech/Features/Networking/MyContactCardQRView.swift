import CoreImage.CIFilterBuiltins
import SwiftUI
import TatumTechKit

/// The user's card as a vCard QR code that any phone camera can scan.
struct MyContactCardQRView: View {
    @Environment(AppModel.self) private var app
    @State private var state: QRState = .loading

    private enum QRState {
        case loading
        case ready(card: ContactCard, qr: UIImage, photo: UIImage?)
        case failed
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                switch state {
                case .loading:
                    ProgressView()
                case .failed:
                    Text("Unable to generate QR code")
                        .multilineTextAlignment(.center)
                case let .ready(card, qr, photo):
                    if let photo {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                            .padding(.bottom, Spacing.sm)
                            .accessibilityLabel("Profile photo")
                    }
                    Text(card.name)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    let subtitle = [card.jobTitle, card.company].compactMap { $0 }.joined(separator: " · ")
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.callout)
                            .multilineTextAlignment(.center)
                    }
                    Image(uiImage: qr)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .padding(Spacing.md)
                        .background(Color.white)
                        .containerRelativeFrame(.horizontal) { width, _ in width * 0.85 }
                        .padding(.top, Spacing.xl)
                        .accessibilityLabel("My Tatum Tech Card QR code")
                    Text("Scan with any camera to save this contact.")
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .padding(.top, Spacing.md)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(Spacing.xl)
        }
        .background(Color.white.ignoresSafeArea())
        .navigationTitle("My Tatum Tech Card")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        let local = app.local
        let user = await local.ensureUser()
        guard let card = await local.contactCard(),
              let vCard = ContactCardVCardCodec.encode(card, firstName: user.firstName, lastName: user.lastName),
              let qr = QRCodeImage.make(from: vCard)
        else {
            state = .failed
            return
        }
        let photo = app.dependencies.contactImages.url(for: card.profileImageFileName).flatMap { UIImage(contentsOfFile: $0.path) }
        state = .ready(card: card, qr: qr, photo: photo)
        await local.addTimelineEntry(.contactCardShared, description: "Shared Tatum Tech contact card")
    }
}

enum QRCodeImage {
    /// A crisp QR code image for `text`, or `nil` if it cannot be encoded.
    static func make(from text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
              let cgImage = CIContext().createCGImage(output, from: output.extent)
        else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
