import SwiftUI

/// Chooses between the launch, signed-out, and signed-in experiences.
struct RootView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        Group {
            switch app.phase {
            case .launching:
                LaunchView()
            case .signedOut:
                AuthFlowView()
            case .signedIn:
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: app.phase)
        .task { await app.start() }
    }
}

/// Matches the system launch screen while the stored account is restored.
private struct LaunchView: View {
    var body: some View {
        ZStack {
            Palette.screenBackground.ignoresSafeArea()
            Image("tatumgames_logo")
                .accessibilityLabel("Tatum Tech")
        }
    }
}
