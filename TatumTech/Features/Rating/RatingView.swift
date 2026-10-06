import StoreKit
import SwiftUI
import TatumTechKit

/// Asks for a 1–5 star rating. Ratings of four or more open the App Store review page.
struct RatingView: View {
    let trigger: RatingTrigger

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    @State private var selectedRating = 0
    @State private var submitted = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    Image("tatumgames_logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 96)
                        .accessibilityHidden(true)
                    Text("Enjoying The Tatum Tech App?")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text("Tatum Tech’s mission is to expand economic opportunity for underserved and underrepresented youth by providing free access to technology, hands-on training, industry mentorship, and real-world experience in AI, game development, and digital production, creating pathways to careers, entrepreneurship, and long-term economic mobility.")
                        .font(.callout)
                        .multilineTextAlignment(.center)
                    Text("Giving us a positive rating helps us continue our mission. How are you enjoying the Tatum Tech app?")
                        .font(.body.weight(.semibold))
                        .multilineTextAlignment(.center)
                    stars
                    Button("Not now") { close() }
                        .buttonStyle(.outlinedAction)
                        .frame(height: 52)
                        .disabled(submitted)
                        .padding(.top, Spacing.xs)
                        .accessibilityIdentifier("rating.notNow")
                }
                .padding(Spacing.xl)
            }
            .background(Color.white.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        close()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                    .disabled(submitted)
                }
            }
        }
        .interactiveDismissDisabled(submitted)
    }

    private var stars: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(1...RatingPolicy.maximumRating, id: \.self) { star in
                Button {
                    submit(star)
                } label: {
                    Image(systemName: "star.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .frame(width: 48, height: 48)
                        .foregroundStyle(star <= selectedRating ? Palette.gold : Palette.mediumGrey)
                }
                .buttonStyle(.plain)
                .disabled(submitted)
                .accessibilityLabel("\(star) of \(RatingPolicy.maximumRating) stars")
                .accessibilityAddTraits(star <= selectedRating ? .isSelected : [])
                .accessibilityIdentifier("rating.star.\(star)")
            }
        }
    }

    private func close() {
        guard !submitted else { return }
        dismiss()
    }

    /// Shows the chosen stars briefly, reports the rating, and sends happy users to the store.
    private func submit(_ rating: Int) {
        guard !submitted else { return }
        submitted = true
        selectedRating = rating
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            let sendToStore = RatingPolicy.shouldSendToStore(rating: rating)
            app.analytics.log(.rateApp(rating: rating, trigger: trigger, sentToStore: sendToStore))
            if sendToStore {
                await app.markSentToAppStore()
                if let url = AppLinks.appStoreReview(appStoreID: app.dependencies.appStoreID) {
                    openURL(url)
                } else {
                    requestReview()
                }
            }
            dismiss()
        }
    }
}
