import Foundation

/// Answers Tatum Tech API requests from JSON bundled with the app instead of the network, wrapped
/// in the same `{"status": ..., "data": ...}` envelope the API returns, so `TatumTechAPIClient`
/// parses both modes identically.
///
/// Served locally:
/// - `GET tatum-tech/upcomingEvents` from `upcoming_events.json`
/// - `GET tatum-tech/events/{id}` and `GET tatum-tech/events/{id}/speakers` (404 if absent)
/// - `GET tatum-tech/partners[?category=]` from `partners.json`, categories mapped to API values
/// - `GET tatum-tech/partners/{id}` (404 if absent)
///
/// Everything else (sign-in, sign-up, refresh, password reset, sign-out, profile update) has no
/// local data and answers **501 Not Implemented** rather than inventing a response.
public struct LocalJSONTransport: HTTPTransport {
    public static let eventsFile = "upcoming_events.json"
    public static let partnersFile = "partners.json"

    /// Category labels used in the bundled `partners.json`, mapped to the API's values.
    static let localPartnerCategories: [String: PartnerCategoryQuery] = [
        "Community Partners": .community,
        "Corporate Partners": .corporate,
        "Education Partners": .education,
        "Game Studio Partners": .gameStudios,
        "Government Partners": .government,
        "Technology Partners": .technology
    ]

    private let loadFile: @Sendable (String) throws -> Data

    /// - Parameter loadFile: Returns the contents of a bundled file by name.
    public init(loadFile: @escaping @Sendable (String) throws -> Data) {
        self.loadFile = loadFile
    }

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        let route = Self.route(of: request.url)
        do {
            return try respond(to: request, route: route)
        } catch {
            return Self.envelope(status: 500, message: "Local JSON could not be read: \(error)")
        }
    }

    private func respond(to request: HTTPRequest, route: [String]) throws -> HTTPResponse {
        guard request.method == .get else { return notImplemented(request, route) }

        switch route.count {
        case 1 where route[0] == "upcomingEvents":
            return Self.success(field: "events", value: try events())
        case 2 where route[0] == "events":
            guard let event = try events().first(where: { Self.identifier($0) == route[1] }) else {
                return Self.notFound("Event '\(route[1])'")
            }
            return Self.success(field: "event", value: event)
        case 3 where route[0] == "events" && route[2] == "speakers":
            guard let event = try events().first(where: { Self.identifier($0) == route[1] }) else {
                return Self.notFound("Event '\(route[1])'")
            }
            return Self.success(field: "speakers", value: event["virtualSpeakers"] ?? [Any]())
        case 1 where route[0] == "partners":
            let category = URLComponents(url: request.url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first { $0.name == "category" }?
                .value
            let partners = try partners().filter { partner in
                guard let category else { return true }
                return (partner["category"] as? String)?.caseInsensitiveCompare(category) == .orderedSame
            }
            return Self.success(field: "partners", value: partners)
        case 2 where route[0] == "partners":
            guard let partner = try partners().first(where: { Self.identifier($0) == route[1] }) else {
                return Self.notFound("Partner '\(route[1])'")
            }
            return Self.success(field: "partner", value: partner)
        default:
            return notImplemented(request, route)
        }
    }

    private func events() throws -> [[String: Any]] {
        try readArray(Self.eventsFile)
    }

    private func partners() throws -> [[String: Any]] {
        try readArray(Self.partnersFile).map { partner in
            var partner = partner
            if let label = partner["category"] as? String, let query = Self.localPartnerCategories[label] {
                partner["category"] = query.rawValue
            }
            return partner
        }
    }

    private func readArray(_ file: String) throws -> [[String: Any]] {
        let object = try JSONSerialization.jsonObject(with: try loadFile(file))
        guard let array = object as? [[String: Any]] else {
            throw APIError.decoding("\(file) is not an array of objects")
        }
        return array
    }

    private func notImplemented(_ request: HTTPRequest, _ route: [String]) -> HTTPResponse {
        Self.envelope(
            status: HTTPStatus.notImplemented,
            message: "\(request.method.rawValue) tatum-tech/\(route.joined(separator: "/")) has no local JSON data; use the network data source"
        )
    }

    private static func notFound(_ what: String) -> HTTPResponse {
        envelope(status: HTTPStatus.notFound, message: "\(what) was not found in local JSON")
    }

    private static func success(field: String, value: Any) -> HTTPResponse {
        envelope(status: 200, message: "OK", data: [field: value])
    }

    private static func envelope(status: Int, message: String, data: [String: Any]? = nil) -> HTTPResponse {
        var object: [String: Any] = ["status": ["statusCode": status, "statusMessage": message]]
        if let data { object["data"] = data }
        let body = (try? JSONSerialization.data(withJSONObject: object)) ?? Data()
        return HTTPResponse(statusCode: status, headers: ["Content-Type": "application/json"], body: body)
    }

    private static func identifier(_ object: [String: Any]) -> String? {
        switch object["id"] {
        case let string as String: string
        case let int as Int: String(int)
        case let double as Double: double.rounded() == double ? String(Int(double)) : String(double)
        default: nil
        }
    }

    /// Decoded path segments after `tatum-tech/`, or every segment for other paths.
    static func route(of url: URL) -> [String] {
        let segments = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        guard let root = segments.firstIndex(of: "tatum-tech") else { return segments }
        return Array(segments[(root + 1)...])
    }
}
