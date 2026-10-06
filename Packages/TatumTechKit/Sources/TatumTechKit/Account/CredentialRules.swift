import Foundation

/// Client-side checks for the sign-in and sign-up forms, shared by every Tatum Tech client.
public enum CredentialRules {
    public static let minimumPasswordLength = 6

    // Same email pattern every Tatum Tech client uses.
    private static let emailPattern =
        "[a-zA-Z0-9+._%\\-]{1,256}@[a-zA-Z0-9][a-zA-Z0-9\\-]{0,64}(\\.[a-zA-Z0-9][a-zA-Z0-9\\-]{0,25})+"

    public static func isValidEmail(_ email: String) -> Bool {
        guard !email.isEmpty,
              let regex = try? NSRegularExpression(pattern: "^\(emailPattern)$")
        else { return false }
        let range = NSRange(email.startIndex..., in: email)
        return regex.firstMatch(in: email, range: range) != nil
    }

    /// At least six characters, no spaces, at least one uppercase letter, and at least one
    /// character that is neither a letter nor a digit.
    public static func isValidPassword(_ password: String) -> Bool {
        password.count >= minimumPasswordLength
            && !password.contains(" ")
            && password.contains { $0.isUppercase }
            && password.contains { !$0.isLetter && !$0.isNumber }
    }
}
