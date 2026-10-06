import ImageIO
import SwiftUI
import UIKit

/// Plays a bundled GIF once and holds its last frame. Shows `fallbackImageName` when animation is
/// off or the GIF cannot be decoded.
struct AnimatedGIFView: UIViewRepresentable {
    let gifName: String
    let fallbackImageName: String
    var animates = true

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        view.isAccessibilityElement = false
        configure(view)
        return view
    }

    func updateUIView(_ view: UIImageView, context: Context) {}

    private func configure(_ view: UIImageView) {
        guard animates, let animation = GIFAnimation.load(named: gifName) else {
            view.image = UIImage(named: fallbackImageName)
            return
        }
        view.image = animation.frames.last
        view.animationImages = animation.frames
        view.animationDuration = animation.duration
        view.animationRepeatCount = 1
        view.startAnimating()
    }
}

/// Decoded frames of a bundled GIF.
struct GIFAnimation {
    let frames: [UIImage]
    let duration: TimeInterval

    static func load(named name: String, bundle: Bundle = .main) -> GIFAnimation? {
        guard let url = bundle.url(forResource: name, withExtension: "gif"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil)
        else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { return nil }
        var frames: [UIImage] = []
        var duration: TimeInterval = 0
        for index in 0..<count {
            guard let image = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            frames.append(UIImage(cgImage: image))
            duration += frameDuration(source: source, index: index)
        }
        guard !frames.isEmpty else { return nil }
        return GIFAnimation(frames: frames, duration: max(duration, 0.1))
    }

    /// The frame's delay; browsers treat delays under 20 ms as 100 ms, and so does this.
    private static func frameDuration(source: CGImageSource, index: Int) -> TimeInterval {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let gif = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        else { return 0.1 }
        let delay = (gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double)
            ?? (gif[kCGImagePropertyGIFDelayTime] as? Double)
            ?? 0.1
        return delay < 0.02 ? 0.1 : delay
    }
}
