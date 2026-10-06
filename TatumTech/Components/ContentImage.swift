import SwiftUI
import UIKit
import TatumTechKit

/// Renders an image referenced by content: a remote URL, a bundled asset name, or a color swatch.
/// Missing or failed images fall back to `placeholder` (or a neutral fill).
struct ContentImage: View {
    let source: ImageSource
    var contentMode: ContentMode = .fill
    /// Bundled asset shown while loading or when the image is unavailable.
    var placeholder: String?

    var body: some View {
        switch source {
        case let .remote(url):
            AsyncImage(url: url, transaction: Transaction(animation: .easeIn(duration: 0.2))) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: contentMode)
                } else {
                    fallback
                }
            }
        case let .bundled(name):
            if UIImage(named: name) != nil {
                Image(name).resizable().aspectRatio(contentMode: contentMode)
            } else {
                fallback
            }
        case let .swatch(name):
            Rectangle().fill(Palette.swatch(named: name))
        case .none:
            fallback
        }
    }

    @ViewBuilder
    private var fallback: some View {
        if let placeholder {
            Image(placeholder).resizable().aspectRatio(contentMode: contentMode)
        } else {
            Rectangle().fill(Palette.disabled)
        }
    }
}

extension ImageSource {
    /// Whether there is a picture worth opening full screen (not a swatch or a missing image).
    var isViewablePicture: Bool {
        switch self {
        case .remote: true
        case let .bundled(name): UIImage(named: name) != nil
        case .swatch, .none: false
        }
    }
}
