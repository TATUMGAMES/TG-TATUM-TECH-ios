import Foundation

extension KeyedDecodingContainer {
    /// Reads an identifier sent either as a JSON string or a number (`"id": 1` and `"id": "1"`
    /// are the same id). Missing or null values become `""`.
    func decodeIdentifier(forKey key: Key) throws -> String {
        if let string = try? decodeIfPresent(String.self, forKey: key) { return string }
        if let int = try? decodeIfPresent(Int.self, forKey: key) { return String(int) }
        if let double = try? decodeIfPresent(Double.self, forKey: key) {
            return double.rounded() == double ? String(Int(double)) : String(double)
        }
        return ""
    }

    func decodeArray<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> [T] {
        try decodeIfPresent([T].self, forKey: key) ?? []
    }
}

/// `{"status": {...}, "data": {...}}`, the envelope around every Tatum Tech API response.
struct ResponseEnvelope<Payload: Decodable>: Decodable {
    let status: ResponseStatus?
    let data: Payload?
}

struct ResponseStatus: Decodable {
    let statusCode: Int?
    let statusMessage: String?
}
