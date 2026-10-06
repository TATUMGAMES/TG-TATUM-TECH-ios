import Foundation

// Request bodies. Optional properties that are nil are omitted from the JSON.

struct EmailSignInRequest: Encodable {
    let email: String
    let password: String
    let deviceId: String
}

struct GoogleSignInRequest: Encodable {
    let googleIdToken: String
    let deviceId: String
}

struct SignUpRequest: Encodable {
    let email: String
    let password: String
    let confirmPassword: String
    let deviceId: String
}

struct RefreshTokenRequest: Encodable {
    let refreshToken: String
    let deviceId: String
}

struct ForgotPasswordRequest: Encodable {
    let email: String
}

struct ResetPasswordRequest: Encodable {
    let verifyToken: String
    let password: String
    let confirmPassword: String?
    let email: String?
}

struct UpdateUserProfileRequest: Encodable {
    let firstName: String?
    let lastName: String?
}

/// `data` of sign-in, sign-up, and refresh-token responses.
public struct AuthSessionDTO: Decodable, Sendable, Equatable {
    public var accessToken: String?
    public var refreshToken: String?
    /// Access token lifetime in seconds.
    public var expiresIn: Int?
    public var tokenType: String?
    public var user: TatumTechUser?

    public init(
        accessToken: String? = nil,
        refreshToken: String? = nil,
        expiresIn: Int? = nil,
        tokenType: String? = nil,
        user: TatumTechUser? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresIn = expiresIn
        self.tokenType = tokenType
        self.user = user
    }
}

/// Tatum Tech account as returned by the API.
public struct TatumTechUser: Codable, Sendable, Hashable {
    public var id: String
    public var anonymousId: String?
    public var username: String?
    public var firstName: String?
    public var lastName: String?
    public var email: String?
    public var createdAt: String?

    public init(
        id: String,
        anonymousId: String? = nil,
        username: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil,
        email: String? = nil,
        createdAt: String? = nil
    ) {
        self.id = id
        self.anonymousId = anonymousId
        self.username = username
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, anonymousId, username, firstName, lastName, email, createdAt
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIdentifier(forKey: .id)
        anonymousId = try container.decodeIfPresent(String.self, forKey: .anonymousId)
        username = try container.decodeIfPresent(String.self, forKey: .username)
        firstName = try container.decodeIfPresent(String.self, forKey: .firstName)
        lastName = try container.decodeIfPresent(String.self, forKey: .lastName)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
    }
}
