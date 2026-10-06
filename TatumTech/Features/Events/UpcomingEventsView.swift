import SwiftUI
import TatumTechKit

struct UpcomingEventsView: View {
    @Environment(AppModel.self) private var app
    @State private var model: UpcomingEventsModel

    init(repository: any ContentRepository) {
        _model = State(initialValue: UpcomingEventsModel(repository: repository))
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.screenBackground.ignoresSafeArea())
            .navigationTitle("Upcoming Events")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await model.load()
                await syncReminders()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            LoadingView()
        case .failed:
            LoadFailedView { Task { await model.reload() } }
        case let .loaded(events):
            ScrollView {
                LazyVStack(spacing: Spacing.lg) {
                    NetworkingContactSection()
                    if events.isEmpty {
                        EmptyStateView(message: "No upcoming events right now.", systemImage: "calendar")
                            .padding(.top, Spacing.xl)
                    }
                    ForEach(events) { event in
                        EventCardView(event: event)
                    }
                }
                .padding(Spacing.md)
            }
            .refreshable {
                await model.reload()
                await syncReminders()
            }
        }
    }

    private func syncReminders() async {
        if case let .loaded(events) = model.state {
            await app.reminders.sync(events: events)
        }
    }
}

/// One event: flyer (tap for full screen), details, Register on Luma, and Virtual Speakers.
struct EventCardView: View {
    let event: Event
    @Environment(\.openURL) private var openURL
    @State private var isImagePresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            flyer

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(event.name)
                    .font(.title2.bold())
                    .foregroundStyle(Palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("Hosted by \(event.host)")
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(.top, Spacing.sm)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                if let start = event.start {
                    Text(start.formatted())
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Palette.textPrimary)
                }
                Text("\(event.location) · \(event.durationHours) hours")
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(.top, Spacing.xs)

            HStack(spacing: Spacing.xs) {
                Button("Register") {
                    if let url = event.registrationURL { openURL(url) }
                }
                .buttonStyle(.filledAction())
                .disabled(!event.canRegister)
                .accessibilityHint("Opens registration on Luma")

                if event.hasVirtualSpeakers {
                    NavigationLink(value: AppRoute.virtualSpeakers(eventID: event.id, speakerID: nil)) {
                        Text("Virtual Speakers")
                    }
                    .buttonStyle(.filledAction())
                }
            }
            .padding(.top, Spacing.sm)
        }
        .padding(Spacing.md)
        .cardSurface()
        .fullScreenCover(isPresented: $isImagePresented) {
            EventImageViewer(event: event)
        }
    }

    @ViewBuilder
    private var flyer: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
        if event.featuredImage.isViewablePicture {
            Button {
                isImagePresented = true
            } label: {
                ContentImage(source: event.featuredImage)
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .overlay(alignment: .bottomLeading) { flyerCaption }
                    .clipShape(shape)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(event.name))
            .accessibilityHint("Shows the event flyer full screen")
        } else {
            ContentImage(source: event.featuredImage)
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .clipShape(shape)
                .accessibilityHidden(true)
        }
    }

    private var flyerCaption: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(event.name)
                .font(.headline)
            Text("Hosted by \(event.host)")
                .font(.caption)
                .opacity(0.9)
        }
        .foregroundStyle(.white)
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
        )
    }
}

/// Full-screen flyer with the event's key details.
private struct EventImageViewer: View {
    let event: Event
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.black.ignoresSafeArea()
            ContentImage(source: event.featuredImage, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel(Text(event.name))

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(event.name).font(.title.bold())
                Text("Hosted by \(event.host)").font(.headline).opacity(0.9)
                if let start = event.start {
                    Text(start.formatted()).font(.subheadline).opacity(0.8)
                }
                Text(event.location).font(.subheadline).opacity(0.8)
            }
            .foregroundStyle(.white)
            .padding(Spacing.xxl)
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .white.opacity(0.3))
                    .frame(minWidth: Metrics.minimumTapTarget, minHeight: Metrics.minimumTapTarget)
            }
            .accessibilityLabel("Close")
            .padding(Spacing.md)
        }
        .onTapGesture { dismiss() }
    }
}
