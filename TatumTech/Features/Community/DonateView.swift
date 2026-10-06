import SwiftUI
import TatumTechKit

/// The mission statement and sponsorship tiers. Each tier opens its checkout page in an in-app
/// browser and records the visit on the timeline.
struct DonateView: View {
    @Environment(AppModel.self) private var app
    @State private var checkout: PresentedURL?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("Our mission is to increase representation of minorities and women in the video game industry. With only 2% of game devs being Black and 3% Latinx, your donation helps us rewrite the future ensuring diverse voices are empowered to create, lead, and innovate.")
                    .font(.system(size: 16))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Choose a donation tier:")
                    .font(.headline)
                    .padding(.top, Spacing.xl)
                    .padding(.bottom, Spacing.md)
                ForEach(DonationTier.allCases) { tier in
                    Button(tier.label) { open(tier) }
                        .buttonStyle(.primary)
                        .padding(.vertical, 6)
                        .accessibilityIdentifier("donate.tier.\(tier.rawValue)")
                }
            }
            .padding(Spacing.md)
        }
        .background(Palette.screenBackground.ignoresSafeArea())
        .navigationTitle("Donate")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $checkout) { page in
            SafariView(url: page.url)
                .ignoresSafeArea()
        }
    }

    private func open(_ tier: DonationTier) {
        checkout = PresentedURL(url: tier.url)
        let local = app.local
        let description = "Visited donation page: \(tier.name) – \(tier.amount)"
        Task { await local.addTimelineEntry(.donation, description: description) }
    }
}
