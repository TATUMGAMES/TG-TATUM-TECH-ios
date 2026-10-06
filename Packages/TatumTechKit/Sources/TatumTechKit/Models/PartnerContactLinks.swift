import Foundation

/// URLs for reaching a partner from the directory.
public enum PartnerContactLinks {
    /// Subject line prefilled on partner emails (same text as the Android app).
    public static let emailSubject = "Got Your Contact Info From Tatum Games. I Have Some Questions"

    /// `mailto:` URL with the subject prefilled, or `nil` for a blank address.
    public static func emailURL(to address: String, subject: String = emailSubject) -> URL? {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = trimmed
        components.queryItems = [URLQueryItem(name: "subject", value: subject)]
        return components.url
    }

    /// `tel:` URL keeping only digits and `+`, or `nil` when no digits remain.
    public static func phoneURL(for number: String) -> URL? {
        let dialable = number.filter { $0.isASCII && ($0.isNumber || $0 == "+") }
        guard dialable.contains(where: \.isNumber) else { return nil }
        return URL(string: "tel:\(dialable)")
    }
}
