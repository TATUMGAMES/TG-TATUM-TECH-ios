import Foundation
import Observation
import TatumTechKit

extension ChallengeTrack {
    var title: String {
        switch self {
        case .coding: "Coding Challenges"
        case .aiLLM: "AI & LLMs"
        case .leetCode: "Leet Code"
        case .mockInterview: "Mock Interviews"
        }
    }
}

/// Feedback shown after an answer is submitted and before it is saved.
struct AnswerFeedback: Equatable {
    let isCorrect: Bool
    let question: ChallengeQuestion
}

/// Drives one challenge screen: the selected bucket, the current session, answer feedback, and
/// the daily limit. An answer is saved when the user taps Continue on its feedback, so leaving
/// mid-feedback never records a half-finished answer.
@MainActor
@Observable
final class ChallengeQuizModel {
    let track: ChallengeTrack
    var language: String
    var level: ChallengeLevel = .beginner

    private(set) var isLoading = true
    private(set) var content: QuizContent = .empty
    private(set) var todayAnswerCount = 0
    private(set) var selectedAnswer = ""
    private(set) var feedback: AnswerFeedback?
    /// Set when this answer crossed the daily limit and the rating prompt should open.
    private(set) var shouldOfferRating = false

    private var engine: ChallengeEngine?
    private var loadGeneration = 0

    init(track: ChallengeTrack) {
        self.track = track
        self.language = track.languages.first ?? ""
    }

    var bucket: ChallengeBucket { ChallengeBucket(track: track, language: language, level: level) }
    var dailyLimit: Int { ChallengeEngine.dailyAnswerLimit }
    var showsLanguageChips: Bool { track.languages.count > 1 }
    var canSubmitToday: Bool { todayAnswerCount < dailyLimit }
    var canDoAnotherChallenge: Bool { todayAnswerCount < dailyLimit }
    var canSubmit: Bool { !selectedAnswer.isEmpty && canSubmitToday && feedback == nil }

    var dailyProgress: Double {
        min(max(Double(todayAnswerCount) / Double(dailyLimit), 0), 1)
    }

    /// Loads (or resumes) the session for the selected language and level.
    func load(using dependencies: AppDependencies) async {
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true
        selectedAnswer = ""
        feedback = nil
        let engine = await engine(using: dependencies)
        let result = await engine.load(bucket)
        guard generation == loadGeneration else { return }
        content = result.content
        todayAnswerCount = result.todayAnswerCount
        isLoading = false
    }

    func select(_ option: String) {
        guard feedback == nil else { return }
        selectedAnswer = option
    }

    /// Shows whether the selected answer is right. Nothing is saved yet.
    func submit() async {
        guard canSubmit, case let .inProgress(session) = content, let question = session.currentQuestion,
              let engine else { return }
        guard await engine.canAnswerMore(bucket) else {
            todayAnswerCount = await engine.todayAnswerCount(bucket)
            content = .dailyLimitReached
            return
        }
        feedback = AnswerFeedback(isCorrect: selectedAnswer == question.correctAnswer, question: question)
    }

    /// Saves the answer under feedback, then moves to the next question or the results.
    func acknowledgeFeedback(eligibleForRating: Bool) async {
        guard feedback != nil, case let .inProgress(session) = content, let engine else {
            feedback = nil
            return
        }
        let answer = selectedAnswer
        let bucket = bucket
        feedback = nil
        let commit = await engine.commit(answer: answer, in: session, bucket: bucket)
        guard bucket == self.bucket else { return }
        content = commit.content
        todayAnswerCount = commit.todayAnswerCount
        selectedAnswer = ""
        if commit.reachedDailyLimit && eligibleForRating {
            shouldOfferRating = true
        }
    }

    func ratingOffered() {
        shouldOfferRating = false
    }

    /// Discards the finished session and starts a new one in the same bucket.
    func startAnotherChallenge(using dependencies: AppDependencies) async {
        let engine = await engine(using: dependencies)
        await engine.reset(bucket)
        await load(using: dependencies)
    }

    private func engine(using dependencies: AppDependencies) async -> ChallengeEngine {
        if let engine { return engine }
        let bank = await dependencies.catalog.questionBank
        let engine = ChallengeEngine(repository: dependencies.local, bank: bank)
        self.engine = engine
        return engine
    }
}
