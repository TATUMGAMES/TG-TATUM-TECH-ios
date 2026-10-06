import SwiftUI
import TatumTechKit

struct VirtualSpeakersView: View {
    @State private var model: VirtualSpeakersModel

    init(eventID: String, repository: any ContentRepository) {
        _model = State(initialValue: VirtualSpeakersModel(eventID: eventID, repository: repository))
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.screenBackground.ignoresSafeArea())
            .navigationTitle("Virtual Speakers")
            .navigationBarTitleDisplayMode(.inline)
            .task { await model.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            LoadingView()
        case .failed:
            LoadFailedView { Task { await model.reload() } }
        case let .loaded(speakers) where speakers.isEmpty:
            EmptyStateView(message: "No virtual speakers for this event", systemImage: "person.wave.2")
        case let .loaded(speakers):
            ScrollView {
                LazyVStack(spacing: Spacing.md) {
                    ForEach(speakers) { speaker in
                        SpeakerCardView(speaker: speaker)
                    }
                }
                .padding(Spacing.md)
            }
            .refreshable { await model.reload() }
        }
    }
}

private struct SpeakerCardView: View {
    let speaker: Speaker
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ContentImage(source: speaker.image, placeholder: "male_profile_default")
                .frame(width: 72, height: 72)
                .clipShape(Circle())
                .accessibilityLabel(photoLabel)

            VStack(alignment: .leading, spacing: 2) {
                Text(speaker.name)
                    .font(.headline)
                    .foregroundStyle(Palette.textPrimary)
                if let company = speaker.companyName {
                    Text(company)
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            .padding(.top, Spacing.xxs)

            if let bio = speaker.bio {
                Text(bio)
                    .font(.subheadline)
                    .foregroundStyle(Palette.textPrimary)
            }

            Text(speaker.topic)
                .font(.body.weight(.semibold))
                .foregroundStyle(Palette.textPrimary)

            if let schedule = speaker.schedule {
                Text(schedule)
                    .font(.subheadline)
                    .foregroundStyle(Palette.textPrimary)
            }
            if let zone = speaker.timeZoneIdentifier {
                Text("Time zone: \(zone)")
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
            }

            Button("Join") {
                if let url = speaker.meetURL { openURL(url) }
            }
            .buttonStyle(.filledAction())
            .disabled(!speaker.canJoin)
            .padding(.top, Spacing.xxs)
            .accessibilityHint("Opens the session in Google Meet")
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private var photoLabel: Text {
        if case .none = speaker.image {
            return Text("Speaker photo placeholder")
        }
        return Text("Photo of \(speaker.name)")
    }
}
