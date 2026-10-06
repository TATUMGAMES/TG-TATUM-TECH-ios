import Foundation

extension EventStart {
    /// Pattern shared across Tatum Tech apps, e.g. "October 10, 2026 at 11:30 AM".
    public static let displayPattern = "MMMM d, yyyy 'at' h:mm a"

    /// The start written in the offset it was published with (not the device's time zone).
    public func formatted(locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = Self.displayPattern
        return formatter.string(from: date)
    }
}
