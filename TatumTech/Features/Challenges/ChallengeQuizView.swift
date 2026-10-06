import SwiftUI
import TatumTechKit

/// A daily challenge track: language and level chips, today's progress, one question at a time,
/// animated answer feedback, and a results card at the end of each ten-question session.
struct ChallengeQuizView: View {
    @Environment(AppModel.self) private var app
    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var model: ChallengeQuizModel

    init(track: ChallengeTrack) {
        _model = State(initialValue: ChallengeQuizModel(track: track))
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    chipSections
                    content
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 10)
            }
            .background(Palette.screenBackground.ignoresSafeArea())

            AnswerFeedbackOverlay(feedback: model.feedback) {
                Task {
                    await model.acknowledgeFeedback(eligibleForRating: await app.isEligibleForRatingPrompt())
                }
            }
        }
        .navigationTitle(model.track.title)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: model.bucket) { await model.load(using: app.dependencies) }
        .onChange(of: model.shouldOfferRating) { _, offer in
            guard offer else { return }
            model.ratingOffered()
            router.ratingTrigger = .codingChallengeComplete
        }
    }

    // MARK: Chips

    @ViewBuilder
    private var chipSections: some View {
        if model.showsLanguageChips {
            sectionTitle("Select a language")
            chipRow(model.track.languages, selected: model.language) { model.language = $0 }
                .padding(.bottom, Spacing.lg)
        }
        sectionTitle("Select a level")
        chipRow(ChallengeLevel.allCases.map(\.rawValue), selected: model.level.rawValue) { value in
            if let level = ChallengeLevel(rawValue: value) { model.level = level }
        }
        .padding(.bottom, Spacing.xl)
    }

    private func sectionTitle(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.title3)
            .foregroundStyle(Palette.textPrimary)
            .padding(.vertical, Spacing.xs)
            .padding(.bottom, Spacing.xs)
            .accessibilityAddTraits(.isHeader)
    }

    private func chipRow(_ values: [String], selected: String, onSelect: @escaping (String) -> Void) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(values, id: \.self) { value in
                    SelectableChip(title: value, isSelected: value == selected) { onSelect(value) }
                        .disabled(model.feedback != nil)
                }
            }
        }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if model.isLoading {
            ProgressView()
                .tint(Palette.brandPrimaryStrong)
                .frame(maxWidth: .infinity)
                .padding(Spacing.xxl)
        } else {
            switch model.content {
            case let .finished(session):
                ChallengeResultsCard(
                    session: session,
                    canDoAnother: model.canDoAnotherChallenge,
                    onDoAnother: { Task { await model.startAnotherChallenge(using: app.dependencies) } },
                    onTryTomorrow: { router.returnHome() }
                )
            case .dailyLimitReached:
                DailyLimitCard()
            case .empty:
                Text("No questions loaded yet.")
                    .foregroundStyle(Palette.textPrimary)
            case let .inProgress(session):
                if let question = session.currentQuestion {
                    questionSection(session: session, question: question)
                } else {
                    Text("Loading…")
                }
            }
        }
    }

    private func questionSection(session: QuizSession, question: ChallengeQuestion) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Progress")
                Spacer()
                Text("\(model.todayAnswerCount)/\(model.dailyLimit)")
                    .monospacedDigit()
            }
            .font(.body.weight(.medium))
            .foregroundStyle(Palette.textPrimary)
            .accessibilityElement(children: .combine)

            ProgressView(value: model.dailyProgress)
                .progressViewStyle(QuizProgressStyle())
                .padding(.top, Spacing.xs)
                .padding(.bottom, Spacing.xl)

            QuestionCard(
                index: session.currentIndex,
                total: session.questions.count,
                question: question,
                showsPatternAndCode: model.track.showsPatternAndCode,
                selectedAnswer: model.selectedAnswer,
                isLocked: model.feedback != nil,
                onSelect: model.select
            )
            .id(question.id)
            .transition(questionTransition)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: question.id)

            Button {
                Task { await model.submit() }
            } label: {
                Text(session.isLastQuestion ? "Submit" : "Next")
            }
            .buttonStyle(QuizButtonStyle())
            .disabled(!model.canSubmit)
            .padding(.top, Spacing.xl)
            .padding(.bottom, Spacing.xl)
            .accessibilityIdentifier("quiz.submit")
        }
    }

    private var questionTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(x: 24)),
            removal: .opacity.combined(with: .offset(x: -24))
        )
    }
}

// MARK: - Components

/// Rounded selectable chip: deep purple when selected, outlined white otherwise.
struct SelectableChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(isSelected ? .white : .black)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .frame(minHeight: 36)
                .background(Capsule().fill(isSelected ? Palette.brandPrimaryStrong : .white))
                .overlay(Capsule().strokeBorder(isSelected ? Palette.brandPrimaryStrong : Palette.mediumGrey, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct QuestionCard: View {
    let index: Int
    let total: Int
    let question: ChallengeQuestion
    let showsPatternAndCode: Bool
    let selectedAnswer: String
    let isLocked: Bool
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Question \(index + 1) of \(total)")
                .font(.title3)
                .foregroundStyle(Palette.brandPrimaryStrong)

            if showsPatternAndCode, !question.pattern.isEmpty {
                Text("Pattern: \(question.pattern)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(RoundedRectangle(cornerRadius: Radius.small).fill(Palette.lavender))
                    .padding(.top, 10)
            }

            if showsPatternAndCode, !question.codeSnippet.isEmpty {
                ScrollView(.horizontal) {
                    Text(question.codeSnippet)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(Palette.textPrimary)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(Spacing.sm)
                }
                .background(RoundedRectangle(cornerRadius: Radius.small).fill(Palette.lightGrey))
                .padding(.top, Spacing.sm)
                .accessibilityLabel("Code snippet")
                .accessibilityValue(question.codeSnippet)
            }

            Text(question.question)
                .font(.body)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.md)

            ForEach(Array(question.options.enumerated()), id: \.element) { offset, option in
                RadioOption(
                    text: "\(Self.letter(offset)). \(option)",
                    isSelected: selectedAnswer == option,
                    isEnabled: !isLocked
                ) { onSelect(option) }
                .padding(.bottom, Spacing.xs)
                .accessibilityIdentifier("quiz.option.\(offset)")
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                .fill(.white)
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
        )
    }

    private static func letter(_ offset: Int) -> String {
        guard let scalar = UnicodeScalar(65 + offset) else { return "\(offset + 1)" }
        return String(Character(scalar))
    }
}

private struct RadioOption: View {
    let text: String
    let isSelected: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: Spacing.sm) {
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Palette.brandPrimaryStrong : Palette.grey, lineWidth: 2)
                        .frame(width: 20, height: 20)
                    if isSelected {
                        Circle()
                            .fill(Palette.brandPrimaryStrong)
                            .frame(width: 10, height: 10)
                    }
                }
                .frame(width: Metrics.minimumTapTarget, height: Metrics.minimumTapTarget)
                Text(text)
                    .font(.callout)
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.6)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct DailyLimitCard: View {
    var body: some View {
        VStack(spacing: Spacing.xs) {
            Text("Daily Limit Reached")
                .font(.title2)
                .foregroundStyle(Palette.brandPrimaryStrong)
            Text("You've answered 30 questions today for this language and difficulty. Come back tomorrow for more challenges!")
                .font(.callout)
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                .fill(.white)
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
        )
    }
}

private struct ChallengeResultsCard: View {
    let session: QuizSession
    let canDoAnother: Bool
    let onDoAnother: () -> Void
    let onTryTomorrow: () -> Void

    var body: some View {
        let results = session.results
        VStack(spacing: 0) {
            Text("Challenge Results")
                .font(.title2)
                .foregroundStyle(Palette.brandPrimaryStrong)
                .padding(.bottom, Spacing.md)
            Text("Score: \(session.correctCount)/\(session.questions.count)")
                .font(.largeTitle)
                .foregroundStyle(Palette.brandPrimaryStrong)
            Text("(\(session.percentCorrect)%)")
                .font(.body)
                .foregroundStyle(Palette.brandPrimaryStrong)
                .padding(.bottom, Spacing.md)

            ForEach(Array(session.questions.enumerated()), id: \.element.id) { offset, question in
                let isCorrect = results[question.id] ?? false
                HStack(spacing: 0) {
                    Text("Q\(offset + 1):")
                        .frame(width: 40, alignment: .leading)
                        .foregroundStyle(Palette.textPrimary)
                    Text(isCorrect ? "✓ Correct" : "✗ Incorrect")
                        .foregroundStyle(isCorrect ? Palette.successGreen : Color(hex: 0xF36C60))
                    Spacer()
                }
                .font(.callout)
                .padding(.vertical, Spacing.xxs)
                .accessibilityElement(children: .combine)
            }

            Button(action: canDoAnother ? onDoAnother : onTryTomorrow) {
                Text(canDoAnother ? "Do Another Challenge" : "Try Again Tomorrow")
            }
            .buttonStyle(QuizButtonStyle())
            .padding(.top, Spacing.xl)
            .accessibilityIdentifier("quiz.results.action")
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                .fill(.white)
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
        )
    }
}

/// Deep purple button with white text, faded when disabled.
struct QuizButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(
                RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                    .fill(Palette.brandPrimaryStrong.opacity(isEnabled ? 1 : 0.5))
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

private struct QuizProgressStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.brandPrimaryStrong.opacity(0.2))
                Capsule()
                    .fill(Palette.brandPrimaryStrong)
                    .frame(width: proxy.size.width * (configuration.fractionCompleted ?? 0))
            }
        }
        .frame(height: 8)
    }
}
