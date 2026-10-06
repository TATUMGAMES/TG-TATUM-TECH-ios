import SwiftUI
import TatumTechKit

/// What MIKROS offers developers who want their game featured.
struct GetYourGameDiscoveredView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("""
                MIKROS is the ecosystem for developers and studios looking to connect their games with Tatum Games' marketing, community, and technology network.

                What participating developers may access:

                • Influencer activation — opportunities to reach audiences through our partnered influencer network (3.2M+).

                • Content & social promotion — writing and social-media marketing capabilities to help games build awareness.

                • Community — exposure through the MIKROS / Tatum Games community, including a 250K+ Discord network.

                • Tatum Tech — eligible games can be considered for inclusion in the Discover Games showcase.

                • Events — eligible participating developers may have opportunities to showcase games through Tatum Games events and programs.
                """)
                .font(.body)
                Button("Learn More About MIKROS") { openURL(AppLinks.mikrosDeveloper) }
                    .buttonStyle(.primary)
                    .padding(.top, Spacing.xs)
                Button("Explainer Video") { openURL(AppLinks.mikrosExplainerVideo) }
                    .buttonStyle(.primary)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.lg)
        }
        .background(Palette.screenBackground.ignoresSafeArea())
        .navigationTitle("Get Your Game Discovered")
        .navigationBarTitleDisplayMode(.inline)
    }
}
