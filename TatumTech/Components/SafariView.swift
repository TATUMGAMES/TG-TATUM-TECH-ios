import SafariServices
import SwiftUI

/// In-app browser for checkout and other web pages that should keep the user inside the app.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

/// A URL presented with `.sheet(item:)` / `.fullScreenCover(item:)`.
struct PresentedURL: Identifiable, Hashable {
    let url: URL
    var id: String { url.absoluteString }
}
