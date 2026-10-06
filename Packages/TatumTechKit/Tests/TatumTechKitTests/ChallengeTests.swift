import Foundation
import Testing
@testable import TatumTechKit

@Suite("Coding challenges")
struct ChallengeTests {
    static let bank = QuestionBank.load(using: BundledContent.data)

    private func calendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func makeEngine() -> (ChallengeEngine, LocalRepository) {
        let repository = LocalRepository(fileURL: nil)
        return (ChallengeEngine(repository: repository, bank: Self.bank, calendar: calendar()), repository)
    }

    @Test func everyBundledFileLoads() {
        #expect(Self.bank.loadIssues.isEmpty, "\(Self.bank.loadIssues)")
        #expect(QuestionBank.fileNames.count == 24)
        #expect(Self.bank.count == 2_400)
    }

    @Test func everyBucketHasAFullPool() {
        for track in ChallengeTrack.allCases {
            for language in track.languages {
                for level in ChallengeLevel.allCases {
                    let pool = Self.bank.questions(language: language, level: level.rawValue)
                    #expect(pool.count == 100, "\(language) \(level.rawValue) has \(pool.count)")
                }
            }
        }
    }

    @Test func bothMockInterviewSpellingsShareOneBucket() {
        let spaced = Self.bank.questions(language: "Mock Interview", level: "Beginner")
        let compact = Self.bank.questions(language: ChallengeLanguage.mockInterview, level: "Beginner")
        #expect(spaced == compact)
        #expect(spaced.count == 100)
    }

    @Test func everyQuestionHasItsAnswerAmongTheOptions() {
        for track in ChallengeTrack.allCases {
            for language in track.languages {
                for level in ChallengeLevel.allCases {
                    for question in Self.bank.questions(language: language, level: level.rawValue) {
                        #expect(question.options.contains(question.correctAnswer), "\(question.id)")
                    }
                }
            }
        }
    }

    @Test func sessionsAreUniqueShuffledAndSized() {
        var generator = SeededGenerator(seed: 7)
        let pool = Self.bank.questions(language: "Kotlin", level: "Beginner")
        let session = QuizSessionBuilder.buildSession(pool: pool, count: 10, using: &generator)
        #expect(session.count == 10)
        #expect(Set(session.map(\.id)).count == 10)
        for question in session {
            let original = Self.bank.question(id: question.id)!
            #expect(Set(question.options) == Set(original.options))
        }
    }

    @Test func sessionSizeRespectsTheDailyLimit() {
        #expect(QuizSessionBuilder.effectiveSessionSize(requested: 10, todayAnswerCount: 0, dailyLimit: 30) == 10)
        #expect(QuizSessionBuilder.effectiveSessionSize(requested: 10, todayAnswerCount: 25, dailyLimit: 30) == 5)
        #expect(QuizSessionBuilder.effectiveSessionSize(requested: 10, todayAnswerCount: 31, dailyLimit: 30) == 0)
    }

    @Test func playingASessionScoresSavesAndRecordsCompletion() async throws {
        let (engine, repository) = makeEngine()
        let bucket = ChallengeBucket(track: .coding, language: "Python", level: .intermediate)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var generator = SeededGenerator(seed: 1)

        let loaded = await engine.load(bucket, now: now, using: &generator)
        guard case .inProgress(var session) = loaded.content else {
            Issue.record("expected a new session, got \(loaded.content)")
            return
        }
        #expect(session.questions.count == 10)

        var lastCommit: AnswerCommit?
        for index in 0..<10 {
            let question = try #require(session.currentQuestion)
            let answer = index < 7 ? question.correctAnswer : question.options.first { $0 != question.correctAnswer }!
            let commit = await engine.commit(answer: answer, in: session, bucket: bucket, now: now)
            lastCommit = commit
            if case .inProgress(let next) = commit.content { session = next }
        }
        guard case .finished(let finished) = lastCommit?.content else {
            Issue.record("expected the session to finish")
            return
        }
        #expect(finished.correctCount == 7)
        #expect(finished.percentCorrect == 70)
        #expect(lastCommit?.todayAnswerCount == 10)

        let data = await repository.snapshot()
        #expect(data.answerEvents.count == 10)
        let completions = data.timeline.filter { $0.type == .challengeCompletion }
        #expect(completions.count == 1)
        #expect(completions.first?.description == "Completed Python Intermediate Challenge")

        // Reloading shows the finished session again without a second completion entry.
        let reloaded = await engine.load(bucket, now: now, using: &generator)
        guard case .finished(let restored) = reloaded.content else {
            Issue.record("expected the finished session to be restored")
            return
        }
        #expect(restored.questions.map(\.options) == finished.questions.map(\.options))
        #expect(await repository.snapshot().timeline.filter { $0.type == .challengeCompletion }.count == 1)
    }

    @Test func anInterruptedSessionResumesWithTheSameOptionOrder() async throws {
        let (engine, _) = makeEngine()
        let bucket = ChallengeBucket(track: .leetCode, language: "LeetCode", level: .advanced)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var generator = SeededGenerator(seed: 3)
        guard case .inProgress(let session) = await engine.load(bucket, now: now, using: &generator).content else {
            Issue.record("expected a session")
            return
        }
        let question = try #require(session.currentQuestion)
        _ = await engine.commit(answer: question.correctAnswer, in: session, bucket: bucket, now: now)

        guard case .inProgress(let resumed) = await engine.load(bucket, now: now, using: &generator).content else {
            Issue.record("expected the session to resume")
            return
        }
        #expect(resumed.currentIndex == 1)
        #expect(resumed.questions.map(\.id) == session.questions.map(\.id))
        #expect(resumed.questions.map(\.options) == session.questions.map(\.options))
        #expect(resumed.answers[question.id] == question.correctAnswer)
    }

    @Test func theDailyLimitBlocksNewSessionsAndIsReportedOnce() async throws {
        let (engine, _) = makeEngine()
        let bucket = ChallengeBucket(track: .aiLLM, language: "AI/LLM", level: .beginner)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var generator = SeededGenerator(seed: 11)
        var limitCrossings = 0

        for _ in 0..<3 {
            guard case .inProgress(var session) = await engine.load(bucket, now: now, using: &generator).content else {
                Issue.record("expected a session")
                return
            }
            while true {
                let question = try #require(session.currentQuestion)
                let commit = await engine.commit(answer: question.correctAnswer, in: session, bucket: bucket, now: now)
                if commit.reachedDailyLimit { limitCrossings += 1 }
                if case .inProgress(let next) = commit.content { session = next } else { break }
            }
            await engine.reset(bucket)
        }
        #expect(limitCrossings == 1)
        #expect(await engine.todayAnswerCount(bucket, now: now) == 30)
        #expect(await engine.load(bucket, now: now, using: &generator).content == .dailyLimitReached)

        // A new day starts fresh.
        let tomorrow = now.addingTimeInterval(24 * 60 * 60)
        guard case .inProgress = await engine.load(bucket, now: tomorrow, using: &generator).content else {
            Issue.record("expected a session the next day")
            return
        }
    }

    @Test func completionsAreCategorisedForStats() {
        let entries = [
            TimelineEntry(id: 1, type: .challengeCompletion, description: "Completed Kotlin Beginner Challenge", timestamp: Date()),
            TimelineEntry(id: 2, type: .challengeCompletion, description: "Completed C# Advanced Challenge", timestamp: Date()),
            TimelineEntry(id: 3, type: .challengeCompletion, description: "Completed Mock Interview Intermediate Challenge", timestamp: Date()),
            TimelineEntry(id: 4, type: .challengeCompletion, description: "Something else", timestamp: Date())
        ]
        let counts = ChallengeCompletion.categoryCounts(entries)
        #expect(counts["Kotlin"] == 1)
        #expect(counts["C#"] == 1)
        #expect(counts["Mock Interview"] == 1)
        #expect(counts.values.reduce(0, +) == 3)
        #expect(ChallengeCompletion.trackLabel(language: ChallengeLanguage.mockInterview, quizRoute: "") == "Mock Interview")
    }

    @Test func relatedIDsMatchJavaStringHashing() {
        #expect(JavaStringHash.hash("") == 0)
        #expect(JavaStringHash.hash("a") == 97)
        #expect(JavaStringHash.hash("hello") == 99_162_322)
        #expect(ChallengeCompletion.encodeIDs(["a/b", "c"]) == #"["a/b","c"]"#)
    }

    @Test func streaksCountConsecutiveDays() {
        let cal = calendar()
        let day: TimeInterval = 24 * 60 * 60
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(StreakCalculator.currentStreak(answerDates: [], calendar: cal) == 0)
        #expect(StreakCalculator.currentStreak(answerDates: [base, base - day, base - 2 * day, base - 4 * day], calendar: cal) == 3)
        #expect(StreakCalculator.currentStreak(answerDates: [base, base + 60], calendar: cal) == 1)
    }

    @Test func bundledAchievementsDecodeAndUnlock() throws {
        let achievements = try Achievement.decodeList(from: BundledContent.data("achievements.json"))
        #expect(achievements.count == 30)
        let challengeBadges = achievements.filter { $0.trackingKey == AchievementKey.challengeCompletion }
        let lowest = try #require(challengeBadges.map(\.threshold).min())
        var data = LocalData()
        for index in 0..<lowest {
            data.appendTimeline(.challengeCompletion, description: "Completed Kotlin Beginner Challenge", relatedID: Int64(index), at: Date())
        }
        let progress = AchievementProgress(data: data)
        #expect(progress.count(for: AchievementKey.challengeCompletion) == lowest)
        #expect(challengeBadges.filter(progress.isUnlocked).count == 1)
        #expect(!AchievementProgress(counts: [:]).isUnlocked(challengeBadges[0]))
    }
}
