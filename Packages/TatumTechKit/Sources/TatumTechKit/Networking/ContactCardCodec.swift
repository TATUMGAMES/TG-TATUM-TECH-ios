import Foundation

/// Contact details read from a scanned QR code, in either the vCard 3.0 or the Tatum Tech
/// JSON format. Profile photos and account credentials are never part of a QR payload.
public struct ContactCardPayload: Codable, Equatable, Sendable {
    public static let type = "tatum_tech_contact"
    public static let currentVersion = 1

    public var type: String
    public var version: Int
    public var cardID: String
    /// Local account id of the card owner; `0` when unknown (vCard scans).
    public var userID: Int64
    /// Stable cross-device identity of the card owner (JSON format only).
    public var anonymousID: String?
    public var name: String
    public var jobTitle: String?
    public var company: String?
    public var description: String?
    public var email: String?
    public var phone: String?
    public var alternateEmail: String?
    public var website: String?
    public var linkedin: String?
    public var twitter: String?
    public var customLink: String?
    public var calendly: String?

    public init(
        type: String = ContactCardPayload.type,
        version: Int = ContactCardPayload.currentVersion,
        cardID: String,
        userID: Int64,
        anonymousID: String? = nil,
        name: String,
        jobTitle: String? = nil,
        company: String? = nil,
        description: String? = nil,
        email: String? = nil,
        phone: String? = nil,
        alternateEmail: String? = nil,
        website: String? = nil,
        linkedin: String? = nil,
        twitter: String? = nil,
        customLink: String? = nil,
        calendly: String? = nil
    ) {
        self.type = type
        self.version = version
        self.cardID = cardID
        self.userID = userID
        self.anonymousID = anonymousID
        self.name = name
        self.jobTitle = jobTitle
        self.company = company
        self.description = description
        self.email = email
        self.phone = phone
        self.alternateEmail = alternateEmail
        self.website = website
        self.linkedin = linkedin
        self.twitter = twitter
        self.customLink = customLink
        self.calendly = calendly
    }

    enum CodingKeys: String, CodingKey {
        case type, version, cardId, userId, anonymousId, name, jobTitle, company, description, email, phone,
             alternateEmail, website, linkedin, twitter, customLink, calendly
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? ""
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 0
        cardID = try container.decodeIfPresent(String.self, forKey: .cardId) ?? ""
        userID = try container.decodeIfPresent(Int64.self, forKey: .userId) ?? 0
        anonymousID = try container.decodeIfPresent(String.self, forKey: .anonymousId)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        jobTitle = try container.decodeIfPresent(String.self, forKey: .jobTitle)
        company = try container.decodeIfPresent(String.self, forKey: .company)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        alternateEmail = try container.decodeIfPresent(String.self, forKey: .alternateEmail)
        website = try container.decodeIfPresent(String.self, forKey: .website)
        linkedin = try container.decodeIfPresent(String.self, forKey: .linkedin)
        twitter = try container.decodeIfPresent(String.self, forKey: .twitter)
        customLink = try container.decodeIfPresent(String.self, forKey: .customLink)
        calendly = try container.decodeIfPresent(String.self, forKey: .calendly)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(version, forKey: .version)
        try container.encode(cardID, forKey: .cardId)
        try container.encode(userID, forKey: .userId)
        try container.encodeIfPresent(anonymousID, forKey: .anonymousId)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(jobTitle, forKey: .jobTitle)
        try container.encodeIfPresent(company, forKey: .company)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(phone, forKey: .phone)
        try container.encodeIfPresent(alternateEmail, forKey: .alternateEmail)
        try container.encodeIfPresent(website, forKey: .website)
        try container.encodeIfPresent(linkedin, forKey: .linkedin)
        try container.encodeIfPresent(twitter, forKey: .twitter)
        try container.encodeIfPresent(customLink, forKey: .customLink)
        try container.encodeIfPresent(calendly, forKey: .calendly)
    }
}

public enum ContactCardParseResult: Equatable, Sendable {
    case success(ContactCardPayload)
    case unsupportedVersion(Int)
    case invalid
}

/// Tatum Tech JSON contact payloads and the scanner entry point.
public enum ContactCardQRCodec {
    public static func payload(from card: ContactCard, anonymousID: String) -> ContactCardPayload {
        ContactCardPayload(
            cardID: card.cardID,
            userID: card.ownerUserID,
            anonymousID: anonymousID,
            name: card.name,
            jobTitle: card.jobTitle,
            company: card.company,
            description: card.description,
            email: card.email,
            phone: card.phone,
            alternateEmail: card.alternateEmail,
            website: card.website,
            linkedin: card.linkedin,
            twitter: card.twitter,
            customLink: card.customLink,
            calendly: card.calendly
        )
    }

    public static func encodeJSON(_ payload: ContactCardPayload) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        guard let data = try? encoder.encode(payload) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    /// Parses scanned QR text: vCard first, then the Tatum Tech JSON format.
    public static func parseIncoming(_ raw: String) -> ContactCardParseResult {
        if raw.isBlankText { return .invalid }
        if ContactCardVCardCodec.isVCard(raw) { return ContactCardVCardCodec.parse(raw) }
        return parseJSON(raw)
    }

    public static func parseJSON(_ raw: String) -> ContactCardParseResult {
        if raw.isBlankText || ContactCardVCardCodec.isVCard(raw) { return .invalid }
        guard let payload = try? JSONDecoder().decode(ContactCardPayload.self, from: Data(raw.utf8)) else {
            return .invalid
        }
        if payload.type != ContactCardPayload.type { return .invalid }
        if payload.cardID.isBlankText || payload.name.isBlankText { return .invalid }
        if payload.version > ContactCardPayload.currentVersion { return .unsupportedVersion(payload.version) }
        if payload.version < 1 { return .invalid }
        return .success(payload)
    }

    /// Whether a scanned card belongs to the current user. The account id is not unique
    /// across devices, so identity uses the anonymous id or else the local card id.
    public static func isOwnCard(_ payload: ContactCardPayload, anonymousID: String, localCardID: String?) -> Bool {
        let payloadAnonymous = payload.anonymousID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !payloadAnonymous.isEmpty { return payloadAnonymous == anonymousID }
        let ownCardID = localCardID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !ownCardID.isEmpty && payload.cardID == ownCardID
    }

    public static func connection(ownerUserID: Int64, payload: ContactCardPayload, connectedAt: Date) -> Connection {
        Connection(
            ownerUserID: ownerUserID,
            connectedCardID: payload.cardID,
            connectedUserID: payload.userID > 0 ? payload.userID : nil,
            connectedAt: connectedAt,
            name: payload.name,
            jobTitle: blankToNil(payload.jobTitle),
            company: blankToNil(payload.company),
            description: blankToNil(payload.description),
            email: blankToNil(payload.email),
            phone: blankToNil(payload.phone),
            alternateEmail: blankToNil(payload.alternateEmail),
            website: blankToNil(payload.website),
            linkedin: blankToNil(payload.linkedin),
            twitter: blankToNil(payload.twitter),
            customLink: blankToNil(payload.customLink),
            calendly: blankToNil(payload.calendly)
        )
    }

    /// Notes saved with a new system contact: the description, then links that have no
    /// dedicated contact field.
    public static func contactNotes(for payload: ContactCardPayload) -> String? {
        var text = ""
        if let description = blankToNil(payload.description) {
            text += description + "\n\n"
        }
        let links = [
            blankToNil(payload.linkedin).map { "LinkedIn: \($0)" },
            blankToNil(payload.twitter).map { "Twitter/X: \($0)" },
            blankToNil(payload.customLink).map { "Link: \($0)" },
            blankToNil(payload.calendly).map { "Calendly: \($0)" }
        ].compactMap { $0 }
        for link in links { text += link + "\n" }
        return blankToNil(text)
    }

    public static func blankToNil(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}

/// vCard 3.0 encoding and parsing so cards can be scanned by any phone camera.
public enum ContactCardVCardCodec {
    static let maxNoteCharacters = 280
    private static let crlf = "\r\n"

    public static func isVCard(_ raw: String) -> Bool {
        let trimmed = raw.drop(while: { $0.isWhitespace })
        return trimmed.prefix(11).uppercased() == "BEGIN:VCARD"
    }

    /// The vCard for `card`, or `nil` when there is no name to share.
    public static func encode(_ card: ContactCard, firstName: String? = nil, lastName: String? = nil) -> String? {
        let blankToNil = ContactCardQRCodec.blankToNil
        let fallbackName = [firstName, lastName].compactMap(blankToNil).joined(separator: " ")
        guard let displayName = blankToNil(card.name) ?? blankToNil(fallbackName) else { return nil }

        var lines = ["BEGIN:VCARD", "VERSION:3.0", "FN:\(escape(displayName))"]
        let given = blankToNil(firstName)
        let family = blankToNil(lastName)
        if given != nil || family != nil {
            lines.append("N:\(escape(family ?? ""));\(escape(given ?? ""));;;")
        } else {
            lines.append("N:;\(escape(displayName));;;")
        }
        if let value = blankToNil(card.jobTitle) { lines.append("TITLE:\(escape(value))") }
        if let value = blankToNil(card.company) { lines.append("ORG:\(escape(value))") }
        if let value = blankToNil(card.phone) { lines.append("TEL;TYPE=CELL:\(escape(value))") }
        if let value = blankToNil(card.email) { lines.append("EMAIL;TYPE=INTERNET:\(escape(value))") }
        if let value = blankToNil(card.alternateEmail) { lines.append("EMAIL;TYPE=INTERNET:\(escape(value))") }
        // URL order matters: parsing assigns unclassified URLs to website, then custom link.
        for url in [card.website, card.linkedin, card.twitter, card.customLink, card.calendly].compactMap(blankToNil) {
            lines.append("URL:\(escape(url))")
        }
        if let description = blankToNil(card.description) {
            let clipped: String
            if description.count <= maxNoteCharacters {
                clipped = description
            } else {
                clipped = String(description.prefix(maxNoteCharacters - 1)).trimmingTrailingWhitespace() + "…"
            }
            lines.append("NOTE:\(escape(clipped))")
        }
        lines.append("UID:\(escape(card.cardID))")
        lines.append("END:VCARD")
        return foldLines(lines).joined(separator: crlf) + crlf
    }

    public static func parse(_ raw: String) -> ContactCardParseResult {
        guard isVCard(raw) else { return .invalid }
        let properties = parseProperties(raw)
        guard !properties.isEmpty else { return .invalid }

        let formattedName = firstValue(properties, "FN")
        let nameParts = firstValue(properties, "N").map { $0.split(separator: ";", maxSplits: 4, omittingEmptySubsequences: false).map(String.init) }
        let family = nameParts.flatMap { $0.count > 0 ? $0[0] : nil }.flatMap { $0.isBlankText ? nil : $0 }
        let given = nameParts.flatMap { $0.count > 1 ? $0[1] : nil }.flatMap { $0.isBlankText ? nil : $0 }
        let displayName: String?
        if let formattedName, !formattedName.isBlankText {
            displayName = formattedName
        } else if given != nil || family != nil {
            displayName = [given, family].compactMap { $0 }.joined(separator: " ")
        } else {
            displayName = nil
        }
        guard let displayName, !displayName.isBlankText else { return .invalid }

        let emails = allValues(properties, "EMAIL")
        let urls = classify(allValues(properties, "URL"))
        let phone = firstValue(properties, "TEL")
        let cardID = firstValue(properties, "UID").flatMap { $0.isBlankText ? nil : $0 }
            ?? syntheticCardID(name: displayName, email: emails.first, phone: phone)

        return .success(ContactCardPayload(
            cardID: cardID,
            userID: 0,
            anonymousID: nil,
            name: displayName,
            jobTitle: firstValue(properties, "TITLE"),
            company: firstValue(properties, "ORG"),
            description: firstValue(properties, "NOTE"),
            email: emails.first,
            phone: phone,
            alternateEmail: emails.count > 1 ? emails[1] : nil,
            website: urls.website,
            linkedin: urls.linkedin,
            twitter: urls.twitter,
            customLink: urls.customLink,
            calendly: urls.calendly
        ))
    }

    // MARK: Escaping and folding

    static func escape(_ value: String) -> String {
        var out = ""
        out.reserveCapacity(value.count)
        for scalar in value.unicodeScalars {
            switch scalar {
            case "\\": out += "\\\\"
            case ";": out += "\\;"
            case ",": out += "\\,"
            case "\n": out += "\\n"
            case "\r": break
            default: out.unicodeScalars.append(scalar)
            }
        }
        return out
    }

    static func unescape(_ value: String) -> String {
        var out = ""
        var scalars = value.unicodeScalars.makeIterator()
        while let scalar = scalars.next() {
            guard scalar == "\\" else {
                out.unicodeScalars.append(scalar)
                continue
            }
            guard let next = scalars.next() else {
                out.unicodeScalars.append(scalar)
                break
            }
            switch next {
            case "n", "N": out += "\n"
            case "\\", ";", ",": out.unicodeScalars.append(next)
            default:
                out.unicodeScalars.append(scalar)
                out.unicodeScalars.append(next)
            }
        }
        return out
    }

    /// Folds lines longer than 75 UTF-8 bytes; continuation lines start with a space.
    static func foldLines(_ lines: [String]) -> [String] {
        var folded: [String] = []
        for line in lines {
            if line.utf8.count <= 75 {
                folded.append(line)
                continue
            }
            var remaining = Substring(line)
            var first = true
            while !remaining.isEmpty {
                let budget = first ? 75 : 74
                var chunkEnd = remaining.startIndex
                var bytes = 0
                for index in remaining.indices {
                    let size = remaining[index].utf8.count
                    if bytes + size > budget { break }
                    bytes += size
                    chunkEnd = remaining.index(after: index)
                }
                if chunkEnd == remaining.startIndex { chunkEnd = remaining.index(after: chunkEnd) }
                let chunk = remaining[remaining.startIndex..<chunkEnd]
                folded.append(first ? String(chunk) : " " + chunk)
                remaining = remaining[chunkEnd...]
                first = false
            }
        }
        return folded
    }

    // MARK: Parsing

    private struct Property {
        let name: String
        let value: String
    }

    private static func parseProperties(_ raw: String) -> [Property] {
        var properties: [Property] = []
        for line in unfold(raw) where !line.isBlankText {
            let upper = line.uppercased()
            if upper == "BEGIN:VCARD" || upper == "END:VCARD" || upper.hasPrefix("VERSION:") { continue }
            guard let colon = line.firstIndex(of: ":"), colon != line.startIndex else { continue }
            let left = line[..<colon]
            let value = unescape(line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces))
            let name = (left.split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? "").uppercased()
            let bareName = name.split(separator: ".", omittingEmptySubsequences: false).last.map(String.init) ?? name
            properties.append(Property(name: bareName, value: value))
        }
        return properties
    }

    private static func unfold(_ raw: String) -> [String] {
        let normalized = raw.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        var out: [String] = []
        for line in normalized.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix(" ") || line.hasPrefix("\t") {
                if !out.isEmpty { out[out.count - 1] += line.dropFirst() }
            } else {
                out.append(String(line))
            }
        }
        return out
    }

    private static func firstValue(_ properties: [Property], _ name: String) -> String? {
        properties.first { $0.name == name && !$0.value.isBlankText }?.value
    }

    private static func allValues(_ properties: [Property], _ name: String) -> [String] {
        properties.filter { $0.name == name && !$0.value.isBlankText }.map(\.value)
    }

    private struct ClassifiedURLs {
        var website: String?
        var linkedin: String?
        var twitter: String?
        var customLink: String?
        var calendly: String?
    }

    private static func classify(_ urls: [String]) -> ClassifiedURLs {
        var result = ClassifiedURLs()
        var leftovers: [String] = []
        for url in urls {
            let lower = url.lowercased()
            if result.linkedin == nil && lower.contains("linkedin.com") {
                result.linkedin = url
            } else if result.twitter == nil && (lower.contains("twitter.com") || isXDomain(lower)) {
                result.twitter = url
            } else if result.calendly == nil && lower.contains("calendly.com") {
                result.calendly = url
            } else {
                leftovers.append(url)
            }
        }
        if leftovers.count > 0 { result.website = leftovers[0] }
        if leftovers.count > 1 { result.customLink = leftovers[1] }
        return result
    }

    /// Matches `(^|[/.])x\.com([/:?]|$)`.
    static func isXDomain(_ lower: String) -> Bool {
        var searchStart = lower.startIndex
        while let range = lower.range(of: "x.com", range: searchStart..<lower.endIndex) {
            let precededOK = range.lowerBound == lower.startIndex || "/.".contains(lower[lower.index(before: range.lowerBound)])
            let followedOK = range.upperBound == lower.endIndex || "/:?".contains(lower[range.upperBound])
            if precededOK && followedOK { return true }
            searchStart = lower.index(after: range.lowerBound)
        }
        return false
    }

    /// Deterministic id for third-party vCards without a UID, so re-scans update one connection.
    static func syntheticCardID(name: String, email: String?, phone: String?) -> String {
        let material = [
            name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            (email ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            (phone ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        ].joined(separator: "|")
        return "vcard:" + String(SHA256Digest.hex(of: Array(material.utf8)).prefix(32))
    }
}

private extension String {
    func trimmingTrailingWhitespace() -> String {
        var result = Substring(self)
        while let last = result.last, last.isWhitespace { result = result.dropLast() }
        return String(result)
    }
}

/// SHA-256 (FIPS 180-4), used only to derive stable local identifiers.
enum SHA256Digest {
    private static let k: [UInt32] = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
    ]

    static func digest(_ message: [UInt8]) -> [UInt8] {
        var h: [UInt32] = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19]
        var padded = message
        padded.append(0x80)
        while padded.count % 64 != 56 { padded.append(0) }
        let bitLength = UInt64(message.count) &* 8
        for shift in stride(from: 56, through: 0, by: -8) {
            padded.append(UInt8(truncatingIfNeeded: bitLength >> UInt64(shift)))
        }

        var w = [UInt32](repeating: 0, count: 64)
        for chunkStart in stride(from: 0, to: padded.count, by: 64) {
            for i in 0..<16 {
                let base = chunkStart + i * 4
                w[i] = UInt32(padded[base]) << 24 | UInt32(padded[base + 1]) << 16 | UInt32(padded[base + 2]) << 8 | UInt32(padded[base + 3])
            }
            for i in 16..<64 {
                let s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3)
                let s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10)
                w[i] = w[i - 16] &+ s0 &+ w[i - 7] &+ s1
            }
            var a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], hh = h[7]
            for i in 0..<64 {
                let s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
                let choice = (e & f) ^ (~e & g)
                let temp1 = hh &+ s1 &+ choice &+ k[i] &+ w[i]
                let s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
                let majority = (a & b) ^ (a & c) ^ (b & c)
                let temp2 = s0 &+ majority
                hh = g; g = f; f = e; e = d &+ temp1
                d = c; c = b; b = a; a = temp1 &+ temp2
            }
            h[0] = h[0] &+ a; h[1] = h[1] &+ b; h[2] = h[2] &+ c; h[3] = h[3] &+ d
            h[4] = h[4] &+ e; h[5] = h[5] &+ f; h[6] = h[6] &+ g; h[7] = h[7] &+ hh
        }
        return h.flatMap { word in (0..<4).map { UInt8(truncatingIfNeeded: word >> UInt32(24 - $0 * 8)) } }
    }

    static func hex(of message: [UInt8]) -> String {
        digest(message).map { byte in
            let hex = String(byte, radix: 16)
            return byte < 16 ? "0" + hex : hex
        }.joined()
    }

    private static func rotr(_ value: UInt32, _ count: UInt32) -> UInt32 {
        (value >> count) | (value << (32 - count))
    }
}
