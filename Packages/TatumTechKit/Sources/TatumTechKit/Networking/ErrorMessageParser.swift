import Foundation

/// Extracts error messages from a non-2xx response body. Never throws; returns `[]` when nothing
/// useful is found.
///
/// Understands the shapes the Tatum Games backends use:
/// - `{"errors": [{"message": ".."}]}` (items may also be plain strings)
/// - `{"error": {"message": ".."}}` or `{"error": ".."}`
/// - `{"message": ".."}`
/// - `{"status": {"statusCode": .., "statusMessage": ".."}}`
public enum ErrorMessageParser {

    public static func messages(from body: Data) -> [String] {
        guard !body.isEmpty,
              let object = try? JSONSerialization.jsonObject(with: body),
              let json = object as? [String: Any]
        else { return [] }

        if let errors = json["errors"] as? [Any] {
            return errors.compactMap(message(in:))
        }
        if let error = json["error"], let message = message(in: error) {
            return [message]
        }
        if let message = nonBlankString(json["message"]) {
            return [message]
        }
        if let status = json["status"] as? [String: Any],
           let message = nonBlankString(status["statusMessage"]) ?? nonBlankString(status["message"]) {
            return [message]
        }
        return []
    }

    private static func message(in element: Any) -> String? {
        if let string = nonBlankString(element) { return string }
        if let object = element as? [String: Any] { return nonBlankString(object["message"]) }
        return nil
    }

    private static func nonBlankString(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
