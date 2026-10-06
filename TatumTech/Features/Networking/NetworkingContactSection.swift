import SwiftUI
import TatumTechKit

/// Card on Upcoming Events for creating, sharing, and scanning Tatum Tech contact cards.
struct NetworkingContactSection: View {
    @Environment(AppModel.self) private var app
    @Environment(AppRouter.self) private var router
    @State private var hasCard = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Share your contact info with friends")
                .font(.headline)
                .foregroundStyle(Palette.textPrimary)
            HStack(spacing: Spacing.xs) {
                if hasCard {
                    action("Edit", id: "networking.edit") { router.push(.contactCardEditor) }
                    action("Share", id: "networking.share") { router.push(.myContactCardQR) }
                } else {
                    action("Create", id: "networking.create") { router.push(.contactCardEditor) }
                }
                action("Scan", id: "networking.scan") { router.push(.scanner(fromUpcomingEvents: true)) }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
        .task { hasCard = await app.local.contactCard() != nil }
    }

    private func action(_ title: LocalizedStringKey, id: String, perform: @escaping () -> Void) -> some View {
        Button(title, action: perform)
            .buttonStyle(.filledAction())
            .accessibilityIdentifier(id)
    }
}
