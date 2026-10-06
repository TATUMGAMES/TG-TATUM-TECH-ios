import SwiftUI

/// A one-shot burst of confetti from `origin`: pieces fly mostly upward, slow down, fall, spin,
/// and fade out over the last 40% of the animation.
struct ConfettiBurst: View {
    let origin: CGPoint
    var pieceCount = 36
    var duration: TimeInterval = 1.6

    @State private var pieces: [Piece] = []
    @State private var start = Date()
    @State private var isFinished = false

    private static let colors: [Color] = [
        Palette.brandPrimary, Palette.brandPrimaryStrong, Palette.successGreen,
        Palette.teal, Palette.gold, Palette.partnerContact
    ]

    struct Piece {
        let angle: Double
        let speed: Double
        let size: CGSize
        let color: Color
        let spin: Double
        let startRotation: Double
    }

    var body: some View {
        if !isFinished {
            TimelineView(.animation) { timeline in
                let t = min(timeline.date.timeIntervalSince(start) / duration, 1)
                Canvas { context, _ in
                    draw(&context, progress: t)
                }
                .onChange(of: t >= 1) { _, done in
                    if done { isFinished = true }
                }
            }
            .onAppear {
                start = Date()
                pieces = (0..<pieceCount).map { _ in Self.randomPiece() }
            }
        }
    }

    private func draw(_ context: inout GraphicsContext, progress t: Double) {
        let travel = 170.0
        let gravity = 420.0
        let alpha = t < 0.6 ? 1 : max(0, 1 - (t - 0.6) / 0.4)
        for piece in pieces {
            let distance = travel * piece.speed * (1 - (1 - t) * (1 - t))
            let x = origin.x + cos(piece.angle) * distance
            let y = origin.y + sin(piece.angle) * distance + gravity * t * t * 0.5
            var pieceContext = context
            pieceContext.translateBy(x: x, y: y)
            pieceContext.rotate(by: .degrees(piece.startRotation + piece.spin * t))
            let rect = CGRect(
                x: -piece.size.width / 2, y: -piece.size.height / 2,
                width: piece.size.width, height: piece.size.height
            )
            pieceContext.fill(Path(rect), with: .color(piece.color.opacity(alpha)))
        }
    }

    private static func randomPiece() -> Piece {
        Piece(
            angle: Double.random(in: -165 ... -15) * .pi / 180,
            speed: Double.random(in: 0.45...1.0),
            size: CGSize(width: Double.random(in: 6...11), height: Double.random(in: 3...7)),
            color: colors.randomElement() ?? Palette.brandPrimary,
            spin: Double.random(in: -360...360),
            startRotation: Double.random(in: 0...360)
        )
    }
}
