import Foundation

/// A family of quizzes with its own home card and stats category.
public enum ChallengeTrack: String, CaseIterable, Hashable, Sendable {
    case coding
    case aiLLM
    case leetCode
    case mockInterview

    /// Stable identifier stored with progress and answers.
    public var routeID: String {
        switch self {
        case .coding: "coding_challenges_screen"
        case .aiLLM: "ai_llm_challenges_screen"
        case .leetCode: "leet_code_challenges_screen"
        case .mockInterview: "mock_interview_challenges_screen"
        }
    }

    /// Question languages offered, in chip order. Tracks with one language show no chips.
    public var languages: [String] {
        switch self {
        case .coding: ["Kotlin", "JavaScript", "Python", "Java", "C#"]
        case .aiLLM: ["AI/LLM"]
        case .leetCode: ["LeetCode"]
        case .mockInterview: [ChallengeLanguage.mockInterview]
        }
    }

    /// LeetCode questions show their pattern and code snippet.
    public var showsPatternAndCode: Bool { self == .leetCode }

    /// Label used when a completed bucket has no language.
    var fallbackLabel: String {
        switch self {
        case .coding: "Coding"
        case .aiLLM: "AI/LLM"
        case .leetCode: "LeetCode"
        case .mockInterview: "Mock Interview"
        }
    }

    public init?(routeID: String) {
        guard let track = Self.allCases.first(where: { $0.routeID == routeID }) else { return nil }
        self = track
    }
}

public enum ChallengeLevel: String, CaseIterable, Hashable, Sendable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
}

public enum ChallengeLanguage {
    /// Canonical language of mock interview questions. Content spells it both
    /// `MockInterview` and `Mock Interview`; both are loaded under this value.
    public static let mockInterview = "MockInterview"

    static func normalized(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.caseInsensitiveCompare("Mock Interview") == .orderedSame ? mockInterview : trimmed
    }
}

/// One multiple-choice question.
public struct ChallengeQuestion: Identifiable, Hashable, Sendable {
    public let id: String
    public let createdAt: String
    public let language: String
    public let level: String
    public let question: String
    public let options: [String]
    public let correctAnswer: String
    /// Explanation, merged with the LeetCode strategy, hints, and complexity when present.
    public let explanation: String
    public let platform: String
    /// LeetCode pattern (or pattern category); empty for other tracks.
    public let pattern: String
    /// Code shown with the question; empty when there is none.
    public let codeSnippet: String

    public init(
        id: String,
        createdAt: String = "",
        language: String,
        level: String,
        question: String,
        options: [String],
        correctAnswer: String,
        explanation: String = "",
        platform: String = "General",
        pattern: String = "",
        codeSnippet: String = ""
    ) {
        self.id = id
        self.createdAt = createdAt
        self.language = language
        self.level = level
        self.question = question
        self.options = options
        self.correctAnswer = correctAnswer
        self.explanation = explanation
        self.platform = platform
        self.pattern = pattern
        self.codeSnippet = codeSnippet
    }

    func withOptions(_ options: [String]) -> ChallengeQuestion {
        ChallengeQuestion(
            id: id, createdAt: createdAt, language: language, level: level, question: question,
            options: options, correctAnswer: correctAnswer, explanation: explanation,
            platform: platform, pattern: pattern, codeSnippet: codeSnippet
        )
    }
}

/// Wire format of a question in the bundled challenge files.
struct ChallengeQuestionDTO: Decodable {
    let id: String?
    let createdAt: String?
    let language: String?
    let level: String?
    let question: String?
    let options: [String]?
    let correctAnswer: String?
    let explanation: String?
    let platform: String?
    let pattern: String?
    let patternCategory: String?
    let strategy: String?
    let hints: [String]?
    let timeComplexity: String?
    let spaceComplexity: String?
    let code: String?

    enum CodingKeys: String, CodingKey {
        case id, language, level, question, options, correctAnswer, explanation, platform
        case pattern, patternCategory, strategy, hints, timeComplexity, spaceComplexity, code
        case createdAt = "created_at"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try? container.decodeIfPresent(String.self, forKey: .id)
        createdAt = try? container.decodeIfPresent(String.self, forKey: .createdAt)
        language = try? container.decodeIfPresent(String.self, forKey: .language)
        level = try? container.decodeIfPresent(String.self, forKey: .level)
        question = try? container.decodeIfPresent(String.self, forKey: .question)
        options = (try? container.decodeIfPresent([LossyString].self, forKey: .options))?.compactMap(\.value)
        correctAnswer = try? container.decodeIfPresent(String.self, forKey: .correctAnswer)
        explanation = try? container.decodeIfPresent(String.self, forKey: .explanation)
        platform = try? container.decodeIfPresent(String.self, forKey: .platform)
        pattern = try? container.decodeIfPresent(String.self, forKey: .pattern)
        patternCategory = try? container.decodeIfPresent(String.self, forKey: .patternCategory)
        strategy = try? container.decodeIfPresent(String.self, forKey: .strategy)
        hints = (try? container.decodeIfPresent([LossyString].self, forKey: .hints))?.compactMap(\.value)
        timeComplexity = try? container.decodeIfPresent(String.self, forKey: .timeComplexity)
        spaceComplexity = try? container.decodeIfPresent(String.self, forKey: .spaceComplexity)
        code = try? container.decodeIfPresent(String.self, forKey: .code)
    }

    var model: ChallengeQuestion {
        ChallengeQuestion(
            id: id ?? "",
            createdAt: createdAt ?? "",
            language: ChallengeLanguage.normalized(language ?? ""),
            level: level ?? "",
            question: question ?? "",
            options: options ?? [],
            correctAnswer: correctAnswer ?? "",
            explanation: Self.appendHintsAndComplexity(
                base: Self.mergeExplanation(explanation, strategy),
                hints: hints ?? [],
                time: timeComplexity,
                space: spaceComplexity
            ),
            platform: platform?.nonBlank ?? "General",
            pattern: pattern?.nonBlank ?? patternCategory?.nonBlank ?? "",
            codeSnippet: code?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        )
    }

    static func mergeExplanation(_ explanation: String?, _ strategy: String?) -> String {
        let exp = explanation?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let strat = strategy?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !exp.isEmpty, !strat.isEmpty, exp != strat { return "\(exp)\n\n\(strat)" }
        return exp.isEmpty ? strat : exp
    }

    static func appendHintsAndComplexity(base: String, hints: [String], time: String?, space: String?) -> String {
        var parts: [String] = []
        if !base.isBlankText { parts.append(base) }
        let lines = hints.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if !lines.isEmpty {
            parts.append("Hints:\n" + lines.map { "• \($0)" }.joined(separator: "\n"))
        }
        let time = time?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let space = space?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let complexity = [
            time.isEmpty ? nil : "Time: \(time)",
            space.isEmpty ? nil : "Space: \(space)"
        ].compactMap { $0 }
        if !complexity.isEmpty { parts.append(complexity.joined(separator: "\n")) }
        return parts.joined(separator: "\n\n")
    }
}

/// Decodes a string, or `nil` for any other JSON value, so one bad entry doesn't drop an array.
struct LossyString: Decodable {
    let value: String?

    init(from decoder: any Decoder) throws {
        value = try? decoder.singleValueContainer().decode(String.self)
    }
}
