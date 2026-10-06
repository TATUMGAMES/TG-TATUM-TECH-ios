import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Public details of the Tatum Tech Discord server.
public struct DiscordServerInfo: Equatable, Sendable {
    public var memberCount: Int?
    public var onlineCount: Int?
    public var serverName: String?
    public var serverIcon: String?
    public var serverBanner: String?
    public var serverDescription: String?
    public var vanityCode: String?
    public var boostLevel: Int?
    public var boostCount: Int?
    public var guildID: String?

    public init(
        memberCount: Int? = nil, onlineCount: Int? = nil, serverName: String? = nil, serverIcon: String? = nil,
        serverBanner: String? = nil, serverDescription: String? = nil, vanityCode: String? = nil,
        boostLevel: Int? = nil, boostCount: Int? = nil, guildID: String? = nil
    ) {
        self.memberCount = memberCount
        self.onlineCount = onlineCount
        self.serverName = serverName
        self.serverIcon = serverIcon
        self.serverBanner = serverBanner
        self.serverDescription = serverDescription
        self.vanityCode = vanityCode
        self.boostLevel = boostLevel
        self.boostCount = boostCount
        self.guildID = guildID
    }

    public var bannerURL: URL? {
        guard let guildID, let serverBanner else { return nil }
        return URL(string: "https://cdn.discordapp.com/banners/\(guildID)/\(serverBanner).png")
    }

    public var iconURL: URL? {
        guard let guildID, let serverIcon else { return nil }
        return URL(string: "https://cdn.discordapp.com/icons/\(guildID)/\(serverIcon).png")
    }

    /// The server's vanity code, or the Tatum Tech invite code.
    public func inviteCode(fallback: String = AppLinks.discordInviteCode) -> String {
        vanityCode ?? fallback
    }

    public static func inviteURL(code: String) -> URL? {
        URL(string: "https://discord.gg/\(code)")
    }

    /// Initial of the server name for the icon placeholder.
    public var initial: String {
        serverName?.first.map(String.init) ?? "M"
    }
}

public enum DiscordError: Error, Equatable, Sendable {
    case http(statusCode: Int)
    case emptyResponse
    case network(String)
    case parse(String)

    /// Shown after "Error: " on the Community screen.
    public var message: String {
        switch self {
        case .http(let statusCode): "HTTP \(statusCode)"
        case .emptyResponse: "Empty response from server"
        case .network(let detail): "Network error: \(detail)"
        case .parse(let detail): "API error: \(detail)"
        }
    }
}

/// Reads the public invite endpoint for live member and presence counts.
public struct DiscordClient: Sendable {
    static let endpointTemplate = "https://discord.com/api/v9/invites/{invite}"

    private let transport: any HTTPTransport
    private let analytics: AnalyticsService
    private let clock: @Sendable () -> Date

    public init(transport: any HTTPTransport, analytics: AnalyticsService, clock: @escaping @Sendable () -> Date = Date.init) {
        self.transport = transport
        self.analytics = analytics
        self.clock = clock
    }

    public func serverInfo(inviteCode: String = AppLinks.discordInviteCode) async throws(DiscordError) -> DiscordServerInfo {
        let started = clock()
        func elapsed() -> Int { Int((clock().timeIntervalSince(started) * 1000).rounded()) }
        guard let url = URL(string: "https://discord.com/api/v9/invites/\(inviteCode)?with_counts=true&with_expiration=true") else {
            throw .parse("invalid invite code")
        }
        let request = HTTPRequest(method: .get, url: url, headers: ["User-Agent": "TatumTech-iOS/1.0", "Accept": "application/json"])

        let response: HTTPResponse
        do {
            response = try await transport.send(request)
        } catch is CancellationError {
            throw .network("cancelled")
        } catch {
            if (error as? URLError)?.code == .cancelled { throw .network("cancelled") }
            analytics.apiError(report(status: nil, duration: elapsed(), type: Self.classify(error)), error: error)
            throw .network(error.localizedDescription)
        }

        guard response.isSuccess else {
            analytics.apiError(report(status: response.statusCode, duration: elapsed(), type: .http))
            throw .http(statusCode: response.statusCode)
        }
        guard !response.body.isEmpty else {
            analytics.apiError(report(status: response.statusCode, duration: elapsed(), type: .parse))
            throw .emptyResponse
        }
        do {
            return try Self.parse(response.body)
        } catch {
            analytics.apiError(report(status: nil, duration: elapsed(), type: .parse), error: error)
            analytics.recordHandled(error)
            throw .parse(String(describing: error))
        }
    }

    private func report(status: Int?, duration: Int, type: APIErrorType) -> APIErrorReport {
        APIErrorReport(endpoint: Self.endpointTemplate, method: "GET", statusCode: status, durationMilliseconds: duration, errorType: type)
    }

    static func classify(_ error: any Error) -> APIErrorType {
        guard let urlError = error as? URLError else { return .io }
        switch urlError.code {
        case .timedOut: return .timeout
        case .notConnectedToInternet, .cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .dnsLookupFailed: return .connection
        default: return .io
        }
    }

    static func parse(_ data: Data) throws -> DiscordServerInfo {
        let dto = try JSONDecoder().decode(InviteDTO.self, from: data)
        func positive(_ value: Int?) -> Int? { value.flatMap { $0 > 0 ? $0 : nil } }
        return DiscordServerInfo(
            memberCount: positive(dto.approximate_member_count),
            onlineCount: positive(dto.approximate_presence_count),
            serverName: dto.guild?.name?.nonBlank,
            serverIcon: dto.guild?.icon?.nonBlank,
            serverBanner: dto.guild?.banner?.nonBlank,
            serverDescription: dto.guild?.description?.nonBlank,
            vanityCode: dto.guild?.vanity_url_code?.nonBlank,
            boostLevel: positive(dto.guild?.premium_tier),
            boostCount: positive(dto.guild?.premium_subscription_count),
            guildID: dto.guild?.id?.nonBlank
        )
    }

    private struct InviteDTO: Decodable {
        struct Guild: Decodable {
            var id: String?
            var name: String?
            var icon: String?
            var banner: String?
            var description: String?
            var vanity_url_code: String?
            var premium_tier: Int?
            var premium_subscription_count: Int?
        }

        var approximate_member_count: Int?
        var approximate_presence_count: Int?
        var guild: Guild?
    }
}
