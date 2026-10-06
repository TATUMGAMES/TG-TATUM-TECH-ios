import Foundation

/// One quiz bucket: a track, language, and level. Progress, daily limits, and completions are per bucket.
public struct ChallengeBucket: Hashable, Sendable {
    public let track: ChallengeTrack
    public let language: String
    public let level: ChallengeLevel

    public init(track: ChallengeTrack, language: String, level: ChallengeLevel) {
        self.track = track
        self.language = ChallengeLanguage.normalized(language)
        self.level = level
    }

    public var progressID: String { "\(track.routeID)|\(language)|\(level.rawValue)" }
}

/// The questions of a session and the answers given so far.
public struct QuizSession: Equatable, Sendable {
    public let questions: [ChallengeQuestion]
    public var currentIndex: Int
    public var answers: [String: String]

    public init(questions: [ChallengeQuestion], currentIndex: Int = 0, answers: [String: String] = [:]) {
        self.questions = questions
        self.currentIndex = currentIndex
        self.answers = answers
    }

    public var currentQuestion: ChallengeQuestion? {
        questions.indices.contains(currentIndex) ? questions[currentIndex] : nil
    }

    public var isLastQuestion: Bool { currentIndex >= questions.count - 1 }

    /// Correctness per question id.
    public var results: [String: Bool] { QuizSessionBuilder.countCorrect(questions, answers: answers).results }
    public var correctCount: Int { QuizSessionBuilder.countCorrect(questions, answers: answers).correct }

    /// Whole-number percentage correct.
    public var percentCorrect: Int {
        questions.isEmpty ? 0 : Int((Double(correctCount) / Double(questions.count) * 100).rounded(.down))
    }
}

/// What the quiz screen shows for a bucket.
public enum QuizContent: Equatable, Sendable {
    /// No questions are available for this bucket.
    case empty
    /// Today's answers for this bucket reached the daily limit.
    case dailyLimitReached
    case inProgress(QuizSession)
    case finished(QuizSession)
}

/// Result of committing one answer.
public struct AnswerCommit: Equatable, Sendable {
    public let content: QuizContent
    public let todayAnswerCount: Int
    /// The daily limit was crossed by this answer (used to offer the rating prompt).
    public let reachedDailyLimit: Bool
}

/// Daily coding challenges: builds sessions from the question bank, saves progress after every
/// answer, enforces the per-bucket daily limit, and records completions on the timeline.
public struct ChallengeEngine: Sendable {
    public static let dailyAnswerLimit = 30
    public static let sessionSize = 10

    private let repository: LocalRepository
    private let bank: QuestionBank
    private let calendar: Calendar

    public init(repository: LocalRepository, bank: QuestionBank, calendar: Calendar = .current) {
        self.repository = repository
        self.bank = bank
        self.calendar = calendar
    }

    /// Restores a saved session (finished or in progress) or starts a new one.
    public func load(_ bucket: ChallengeBucket, now: Date = Date()) async -> (content: QuizContent, todayAnswerCount: Int) {
        var generator = SystemRandomNumberGenerator()
        return await load(bucket, now: now, using: &generator)
    }

    public func load<G: RandomNumberGenerator>(
        _ bucket: ChallengeBucket,
        now: Date,
        using generator: inout G
    ) async -> (content: QuizContent, todayAnswerCount: Int) {
        let today = await todayAnswerCount(bucket, now: now)
        if let saved = await repository.store.read({ $0.quizProgress[bucket.progressID] }) {
            let questions = restore(saved)
            guard !questions.isEmpty else { return (.empty, today) }
            if saved.isCompleted {
                await recordCompletionIfAbsent(saved)
                return (.finished(QuizSession(questions: questions, currentIndex: 0, answers: saved.answers)), today)
            }
            let index = min(max(saved.currentIndex, 0), max(questions.count - 1, 0))
            return (.inProgress(QuizSession(questions: questions, currentIndex: index, answers: saved.answers)), today)
        }

        if today >= Self.dailyAnswerLimit { return (.dailyLimitReached, today) }
        let size = QuizSessionBuilder.effectiveSessionSize(
            requested: Self.sessionSize, todayAnswerCount: today, dailyLimit: Self.dailyAnswerLimit
        )
        guard size > 0 else { return (.dailyLimitReached, today) }
        let pool = bank.questions(language: bucket.language, level: bucket.level.rawValue)
        let questions = QuizSessionBuilder.buildSession(pool: pool, count: size, using: &generator)
        guard !questions.isEmpty else { return (.empty, today) }

        let progress = QuizProgress(
            id: bucket.progressID,
            quizRoute: bucket.track.routeID,
            language: bucket.language,
            level: bucket.level.rawValue,
            currentIndex: 0,
            answers: [:],
            questionIDs: questions.map(\.id),
            optionOrder: Dictionary(uniqueKeysWithValues: questions.map { ($0.id, $0.options) }),
            isCompleted: false,
            lastUpdated: now
        )
        await repository.store.update { $0.quizProgress[progress.id] = progress }
        return (.inProgress(QuizSession(questions: questions)), today)
    }

    /// Answers given today in `bucket`.
    public func todayAnswerCount(_ bucket: ChallengeBucket, now: Date = Date()) async -> Int {
        let start = calendar.startOfDay(for: now)
        let route = bucket.track.routeID
        let language = bucket.language
        let level = bucket.level.rawValue
        return await repository.store.read { data in
            data.answerEvents.filter {
                $0.timestamp >= start && $0.quizRoute == route && $0.language == language && $0.level == level
            }.count
        }
    }

    public func canAnswerMore(_ bucket: ChallengeBucket, now: Date = Date()) async -> Bool {
        await todayAnswerCount(bucket, now: now) < Self.dailyAnswerLimit
    }

    /// Saves `answer` to the current question, then advances or finishes the session.
    public func commit(
        answer: String,
        in session: QuizSession,
        bucket: ChallengeBucket,
        now: Date = Date()
    ) async -> AnswerCommit {
        guard let question = session.currentQuestion else {
            let today = await todayAnswerCount(bucket, now: now)
            return AnswerCommit(content: .inProgress(session), todayAnswerCount: today, reachedDailyLimit: false)
        }
        let before = await todayAnswerCount(bucket, now: now)
        let event = QuizAnswerEvent(
            quizRoute: bucket.track.routeID,
            language: bucket.language,
            level: bucket.level.rawValue,
            questionID: question.id,
            answerChosen: answer,
            isCorrect: answer == question.correctAnswer,
            timestamp: now
        )
        var updated = session
        updated.answers[question.id] = answer
        let finished = session.isLastQuestion
        if !finished { updated.currentIndex = session.currentIndex + 1 }

        let progress = QuizProgress(
            id: bucket.progressID,
            quizRoute: bucket.track.routeID,
            language: bucket.language,
            level: bucket.level.rawValue,
            currentIndex: finished ? session.currentIndex : updated.currentIndex,
            answers: updated.answers,
            questionIDs: session.questions.map(\.id),
            optionOrder: Dictionary(uniqueKeysWithValues: session.questions.map { ($0.id, $0.options) }),
            isCompleted: finished,
            lastUpdated: now
        )
        await repository.store.update { data in
            data.answerEvents.append(event)
            data.quizProgress[progress.id] = progress
        }
        if finished { await recordCompletionIfAbsent(progress) }

        let after = await todayAnswerCount(bucket, now: now)
        let crossed = before < Self.dailyAnswerLimit && after >= Self.dailyAnswerLimit
        if finished {
            updated.currentIndex = 0
            return AnswerCommit(content: .finished(updated), todayAnswerCount: after, reachedDailyLimit: crossed)
        }
        return AnswerCommit(content: .inProgress(updated), todayAnswerCount: after, reachedDailyLimit: crossed)
    }

    /// Discards the bucket's saved session so the next load starts a new one.
    public func reset(_ bucket: ChallengeBucket) async {
        await repository.store.update { $0.quizProgress[bucket.progressID] = nil }
    }

    /// Adds any missing completion entries for finished sessions.
    @discardableResult
    public func backfillCompletions() async -> Int {
        let completed = await repository.store.read { data in data.quizProgress.values.filter(\.isCompleted) }
        var inserted = 0
        for progress in completed.sorted(by: { $0.lastUpdated < $1.lastUpdated }) {
            if await recordCompletionIfAbsent(progress) { inserted += 1 }
        }
        return inserted
    }

    /// Consecutive days with at least one answer, counting back from the most recent such day.
    public func currentStreak() async -> Int {
        let dates = await repository.store.read { data in data.answerEvents.map(\.timestamp) }
        return StreakCalculator.currentStreak(answerDates: dates, calendar: calendar)
    }

    @discardableResult
    private func recordCompletionIfAbsent(_ progress: QuizProgress) async -> Bool {
        let related = ChallengeCompletion.relatedID(progressID: progress.id, questionIDs: progress.questionIDs)
        let description = ChallengeCompletion.description(
            label: ChallengeCompletion.trackLabel(language: progress.language, quizRoute: progress.quizRoute),
            level: progress.level
        )
        let timestamp = progress.lastUpdated
        return await repository.store.update { data in
            let exists = data.timeline.contains { $0.type == .challengeCompletion && $0.relatedID == related }
            guard !exists else { return false }
            data.appendTimeline(.challengeCompletion, description: description, relatedID: related, at: timestamp)
            return true
        }
    }

    private func restore(_ progress: QuizProgress) -> [ChallengeQuestion] {
        progress.questionIDs.compactMap { id in
            guard let question = bank.question(id: id) else { return nil }
            let saved = progress.optionOrder[id] ?? []
            let original = question.options.distinctPreservingOrder()
            let isSameSet = saved.count == original.count && Set(saved) == Set(original)
            return question.withOptions(isSameSet ? saved : original)
        }
    }
}

public enum StreakCalculator {
    /// Consecutive calendar days with activity, counted back from the most recent active day.
    public static func currentStreak(answerDates: [Date], calendar: Calendar) -> Int {
        let days = Set(answerDates.map { calendar.startOfDay(for: $0) }).sorted(by: >)
        guard var previous = days.first else { return 0 }
        var streak = 1
        for day in days.dropFirst() {
            let gap = calendar.dateComponents([.day], from: day, to: previous).day ?? 0
            if gap == 1 {
                streak += 1
                previous = day
            } else if gap > 1 {
                break
            }
        }
        return streak
    }
}
