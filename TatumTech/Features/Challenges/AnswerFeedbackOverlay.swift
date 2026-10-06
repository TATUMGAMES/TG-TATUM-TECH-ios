import SwiftUI
import TatumTechKit

/// Full-screen answer feedback: a dimmed backdrop with an accent pulse, a card with the animated
/// result icon, the correct answer when wrong, the explanation, and Continue. Correct answers
/// burst confetti from the icon; wrong answers shake the card.
struct AnswerFeedbackOverlay: View {
    let feedback: AnswerFeedback?
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let explanationFallback = "Review the correct answer and try a similar question next time to reinforce this concept."

    var body: some View {
        ZStack {
            if let feedback {
                FeedbackContent(feedback: feedback, reduceMotion: reduceMotion, onContinue: onContinue)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: reduceMotion ? 1 : 0.92)),
                            removal: .opacity
                        )
                    )
            }
        }
        .animation(.easeOut(duration: reduceMotion ? 0 : 0.22), value: feedback)
        .sensoryFeedback(trigger: feedback) { _, newValue in
            guard let newValue else { return nil }
            return newValue.isCorrect ? .success : .error
        }
    }
}

private struct FeedbackContent: View {
    let feedback: AnswerFeedback
    let reduceMotion: Bool
    let onContinue: () -> Void

    @State private var iconCenter: CGPoint?
    @State private var shakeOffset: CGFloat = 0

    private var accent: Color { feedback.isCorrect ? Palette.successGreen : Color(hex: 0xF36C60) }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {}
                .accessibilityHidden(true)

            FeedbackBackdrop(accent: accent, reduceMotion: reduceMotion)
                .id(feedback.isCorrect)
                .allowsHitTesting(false)

            card
                .offset(x: shakeOffset)
                .padding(.horizontal, Spacing.xl)
                .task(id: feedback.question.id) { await shakeIfIncorrect() }

            if feedback.isCorrect, !reduceMotion, let iconCenter {
                ConfettiBurst(origin: iconCenter)
                    .id(feedback.question.id)
                    .allowsHitTesting(false)
            }
        }
        .coordinateSpace(.named(Self.space))
        .accessibilityAddTraits(.isModal)
    }

    private static let space = "answerFeedback"

    private var card: some View {
        ScrollView {
            VStack(spacing: 0) {
                FeedbackIcon(isCorrect: feedback.isCorrect, reduceMotion: reduceMotion)
                    .onGeometryChange(for: CGPoint.self) { proxy in
                        let frame = proxy.frame(in: .named(Self.space))
                        return CGPoint(x: frame.midX, y: frame.midY)
                    } action: { center in
                        iconCenter = center
                    }

                Text(feedback.isCorrect ? "✓ Correct!" : "✕ Not quite.")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(accent)
                    .multilineTextAlignment(.center)
                    .padding(.top, Spacing.sm)
                    .accessibilityAddTraits(.isHeader)

                if !feedback.isCorrect, !feedback.question.correctAnswer.isEmpty {
                    Text("Correct Answer: \(feedback.question.correctAnswer)")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Palette.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 10)
                }

                Text(explanation)
                    .font(.callout)
                    .foregroundStyle(Palette.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(hex: 0xE0E0E0))
                    .padding(.top, Spacing.sm)

                Button("Continue", action: onContinue)
                    .buttonStyle(QuizButtonStyle())
                    .padding(.top, Spacing.lg)
                    .accessibilityIdentifier("quiz.feedback.continue")
            }
            .padding(Spacing.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxHeight: 560)
        .background(
            RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                .fill(.white)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        )
    }

    private var explanation: String {
        let text = feedback.question.explanation.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? AnswerFeedbackOverlay.explanationFallback : text
    }

    private func shakeIfIncorrect() async {
        guard !feedback.isCorrect, !reduceMotion else { return }
        for offset: CGFloat in [-8, 8, -5, 5, -2, 0] {
            withAnimation(.linear(duration: 0.028)) { shakeOffset = offset }
            try? await Task.sleep(for: .milliseconds(28))
        }
    }
}

/// Soft accent glow that pulses, plus a ring that expands once.
private struct FeedbackBackdrop: View {
    let accent: Color
    let reduceMotion: Bool

    @State private var pulse = false
    @State private var ring: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let radius = min(size.width, size.height) * 0.42
            let center = CGPoint(x: size.width / 2, y: size.height * 0.38)
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [accent.opacity(reduceMotion ? 0.22 : (pulse ? 0.32 : 0.18)), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: radius
                    ))
                    .frame(width: radius * 2, height: radius * 2)
                    .position(center)
                Circle()
                    .stroke(accent.opacity(0.35 * ring), lineWidth: 3)
                    .frame(width: radius * 0.857 * ring, height: radius * 0.857 * ring)
                    .position(center)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            if reduceMotion {
                ring = 1
            } else {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
                withAnimation(.easeOut(duration: 0.42)) { ring = 1 }
            }
        }
    }
}

/// The animated result icon. It springs in from 60% scale and plays its animation once.
private struct FeedbackIcon: View {
    let isCorrect: Bool
    let reduceMotion: Bool
    @State private var scale: CGFloat = 0.6

    var body: some View {
        AnimatedGIFView(
            gifName: isCorrect ? "animated_coding_challenge_correct" : "animated_coding_challenge_incorrect",
            fallbackImageName: isCorrect ? "coding_challenge_correct" : "coding_challenge_incorrect",
            animates: !reduceMotion
        )
        .id(isCorrect)
        .frame(width: 96, height: 96)
        .scaleEffect(reduceMotion ? 1 : scale)
        .accessibilityLabel(isCorrect ? "Answer correct" : "Answer incorrect")
        .onAppear {
            guard !reduceMotion else { return }
            scale = 0.6
            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { scale = 1 }
        }
    }
}
