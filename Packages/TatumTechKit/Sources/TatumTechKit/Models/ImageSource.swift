import Foundation

/// Where an image referenced by content comes from.
///
/// Content (API or bundled JSON) refers to images as a remote URL, the name of an image bundled
/// with the app (optionally prefixed `drawable:`, as shared content writes it),
/// or a solid swatch written `color://<name>`.
public enum ImageSource: Hashable, Sendable {
    case remote(URL)
    case bundled(name: String)
    case swatch(name: String)
    case none

    public init(contentValue: String?) {
        let value = contentValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let lowercased = value.lowercased()
        if value.isEmpty {
            self = .none
        } else if lowercased.hasPrefix("color://") {
            self = .swatch(name: String(value.dropFirst("color://".count)))
        } else if lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://") {
            self = URL(string: value).map(ImageSource.remote) ?? .none
        } else if lowercased.hasPrefix("drawable:") {
            let name = String(value.dropFirst("drawable:".count))
            self = name.isEmpty ? .none : .bundled(name: name)
        } else {
            self = .bundled(name: value)
        }
    }
}

extension URL {
    /// A URL from content text, or `nil` for blank or unparsable values.
    init?(contentValue: String?) {
        guard let value = contentValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty,
              let url = URL(string: value),
              url.scheme != nil
        else { return nil }
        self = url
    }
}

extension String {
    /// `nil` for blank text, otherwise the trimmed text.
    var nonBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
