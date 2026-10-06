import Foundation

/// Every bundled challenge question, loaded once from the challenge JSON files.
public struct QuestionBank: Sendable {
    /// Bundled challenge files: five languages, AI/LLM, LeetCode, and mock interviews at three levels.
    public static let fileNames: [String] = {
        let stems = ["javascript", "kotlin", "python", "java", "csharp", "ai_llm", "leet", "mock_interview"]
        let levels = ["beginner", "intermediate", "advanced"]
        return stems.flatMap { stem in levels.map { "coding_challenges_\(stem)_\($0).json" } }
    }()

    /// Questions by id. A later file wins when two files share an id.
    private let byID: [String: ChallengeQuestion]
    private let byBucket: [String: [ChallengeQuestion]]
    /// Files that could not be read or decoded, with the reason.
    public let loadIssues: [String]

    public init(questions: [ChallengeQuestion], loadIssues: [String] = []) {
        var byID: [String: ChallengeQuestion] = [:]
        var order: [String] = []
        for question in questions where !question.id.isEmpty {
            if byID[question.id] == nil { order.append(question.id) }
            byID[question.id] = question
        }
        self.byID = byID
        self.byBucket = Dictionary(grouping: order.compactMap { byID[$0] }) { Self.bucketKey($0.language, $0.level) }
        self.loadIssues = loadIssues
    }

    /// Loads every file in `fileNames`. A file that fails is skipped and listed in `loadIssues`.
    public static func load(using loadFile: (String) throws -> Data) -> QuestionBank {
        var questions: [ChallengeQuestion] = []
        var issues: [String] = []
        let decoder = JSONDecoder()
        for name in fileNames {
            do {
                let dtos = try decoder.decode([ChallengeQuestionDTO].self, from: try loadFile(name))
                questions.append(contentsOf: dtos.map(\.model))
            } catch {
                issues.append("\(name): \(error)")
            }
        }
        return QuestionBank(questions: questions, loadIssues: issues)
    }

    public var count: Int { byID.count }
    public var isEmpty: Bool { byID.isEmpty }

    public func questions(language: String, level: String) -> [ChallengeQuestion] {
        byBucket[Self.bucketKey(ChallengeLanguage.normalized(language), level)] ?? []
    }

    public func question(id: String) -> ChallengeQuestion? {
        byID[id]
    }

    private static func bucketKey(_ language: String, _ level: String) -> String {
        "\(language)|\(level)"
    }
}

/// Pure helpers for building a quiz session from a question pool.
public enum QuizSessionBuilder {
    /// Up to `count` unique questions in random order, each with distinct options shuffled.
    /// Questions whose correct answer is not among their options are skipped.
    public static func buildSession<G: RandomNumberGenerator>(
        pool: [ChallengeQuestion],
        count: Int,
        using generator: inout G
    ) -> [ChallengeQuestion] {
        guard count > 0 else { return [] }
        var seen = Set<String>()
        let unique = pool.filter { !$0.id.isBlankText && seen.insert($0.id).inserted }
        var session: [ChallengeQuestion] = []
        for question in unique.shuffled(using: &generator) {
            guard session.count < count else { break }
            if let shuffled = shuffleOptions(question, using: &generator) { session.append(shuffled) }
        }
        return session
    }

    /// The question with distinct options shuffled, or `nil` if the correct answer is missing.
    public static func shuffleOptions<G: RandomNumberGenerator>(
        _ question: ChallengeQuestion,
        using generator: inout G
    ) -> ChallengeQuestion? {
        let options = question.options.distinctPreservingOrder()
        guard options.contains(question.correctAnswer) else { return nil }
        return question.withOptions(options.shuffled(using: &generator))
    }

    /// Correctness per question (unanswered counts as incorrect) and the number correct.
    public static func countCorrect(
        _ questions: [ChallengeQuestion],
        answers: [String: String]
    ) -> (results: [String: Bool], correct: Int) {
        var results: [String: Bool] = [:]
        for question in questions {
            results[question.id] = answers[question.id].map { $0 == question.correctAnswer } ?? false
        }
        return (results, results.values.filter { $0 }.count)
    }

    /// Questions to serve so today's answers never exceed `dailyLimit`.
    public static func effectiveSessionSize(requested: Int, todayAnswerCount: Int, dailyLimit: Int) -> Int {
        min(requested, max(0, dailyLimit - todayAnswerCount))
    }
}

/// Records finished quizzes on the timeline and counts them per category for stats.
public enum ChallengeCompletion {
    /// Categories shown in the stats breakdown, in order.
    public static let statsCategories = ["Kotlin", "Java", "JavaScript", "Python", "C#", "AI/LLM", "LeetCode", "Mock Interview"]

    public static func trackLabel(language: String, quizRoute: String) -> String {
        if language == ChallengeLanguage.mockInterview { return "Mock Interview" }
        if !language.isBlankText { return language }
        return ChallengeTrack(routeID: quizRoute)?.fallbackLabel ?? "Coding"
    }

    /// e.g. "Completed Kotlin Beginner Challenge".
    public static func description(label: String, level: String) -> String {
        "Completed \(label.isBlankText ? "Coding" : label) \(level) Challenge"
    }

    /// Stable id tying a timeline entry to one finished session, so it is recorded only once.
    public static func relatedID(progressID: String, questionIDs: [String]) -> Int64 {
        Int64(JavaStringHash.hash("\(progressID)|\(encodeIDs(questionIDs))"))
    }

    /// The category named in a completion description, if any.
    public static func category(fromDescription description: String) -> String? {
        let text = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = "Completed "
        let suffix = " Challenge"
        guard text.hasPrefix(prefix), text.hasSuffix(suffix), text.count > prefix.count + suffix.count else { return nil }
        let middle = text.dropFirst(prefix.count).dropLast(suffix.count)
        for level in ChallengeLevel.allCases {
            let levelSuffix = " \(level.rawValue)"
            if middle.hasSuffix(levelSuffix) {
                let category = String(middle.dropLast(levelSuffix.count))
                return category.isEmpty ? nil : category
            }
        }
        return nil
    }

    /// Completions per stats category (every category present, zero when none).
    public static func categoryCounts(_ completions: [TimelineEntry]) -> [String: Int] {
        var counts = Dictionary(uniqueKeysWithValues: statsCategories.map { ($0, 0) })
        for entry in completions {
            guard let raw = category(fromDescription: entry.description),
                  let key = statsCategories.first(where: { $0.caseInsensitiveCompare(raw) == .orderedSame })
            else { continue }
            counts[key, default: 0] += 1
        }
        return counts
    }

    /// Question ids in the compact JSON array form used for the related id.
    static func encodeIDs(_ ids: [String]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        let data = (try? encoder.encode(ids)) ?? Data("[]".utf8)
        return String(decoding: data, as: UTF8.self)
    }
}

/// Java's `String.hashCode`, so derived ids are stable across launches and platforms.
enum JavaStringHash {
    static func hash(_ text: String) -> Int32 {
        var hash: Int32 = 0
        for unit in text.utf16 {
            hash = hash &* 31 &+ Int32(unit)
        }
        return hash
    }
}

extension Array where Element: Hashable {
    func distinctPreservingOrder() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
