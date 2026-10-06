import SwiftUI
import TatumTechKit

struct VirtualSpeakersView: View {
    @State private var model: VirtualSpeakersModel
    private let highlightedSpeakerID: String?

    /// `highlightedSpeakerID` is the speaker a reminder was opened for; the list scrolls to them.
    init(eventID: String, highlightedSpeakerID: String? = nil, repository: any ContentRepository) {
        _model = State(initialValue: VirtualSpeakersModel(eventID: eventID, repository: repository))
        self.highlightedSpeakerID = highlightedSpeakerID
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
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: Spacing.md) {
                        ForEach(speakers) { speaker in
                            SpeakerCardView(
                                speaker: speaker,
                                eventID: model.eventID,
                                isHighlighted: speaker.id == highlightedSpeakerID
                            )
                            .id(speaker.id)
                        }
                    }
                    .padding(Spacing.md)
                }
                .refreshable { await model.reload() }
                .task(id: highlightedSpeakerID) {
                    guard let highlightedSpeakerID, speakers.contains(where: { $0.id == highlightedSpeakerID }) else { return }
                    withAnimation { proxy.scrollTo(highlightedSpeakerID, anchor: .top) }
                }
            }
        }
    }
}

private struct SpeakerCardView: View {
    let speaker: Speaker
    let eventID: String
    let isHighlighted: Bool
    @Environment(\.openURL) private var openURL
    #if DEBUG
    @Environment(AppModel.self) private var app
    @State private var testReminderScheduled = false
    #endif

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

            #if DEBUG
            Button("Test reminder in 10 s (debug)") {
                Task {
                    await app.reminders.scheduleTestReminder(eventID: eventID, speaker: speaker)
                    testReminderScheduled = true
                }
            }
            .buttonStyle(.outlinedAction)
            if testReminderScheduled {
                Text("Reminder in 10 seconds. Leave the app to get the system notification instead of the banner.")
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            #endif
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
        .overlay {
            if isHighlighted {
                RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                    .stroke(Palette.brandPrimary, lineWidth: 2)
            }
        }
    }

    private var photoLabel: Text {
        if case .none = speaker.image {
            return Text("Default speaker photo")
        }
        return Text("Photo of \(speaker.name)")
    }
}
