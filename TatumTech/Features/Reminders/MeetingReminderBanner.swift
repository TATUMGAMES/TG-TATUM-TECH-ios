import SwiftUI
import TatumTechKit

/// Dark banner across the top of the screen while a reminder is due in the foreground.
struct MeetingReminderBannerHost: View {
    @Environment(MeetingReminderCenter.self) private var reminders

    var body: some View {
        VStack {
            if let reminder = reminders.banner {
                MeetingReminderBanner(
                    reminder: reminder,
                    onOpen: { withAnimation(.easeOut(duration: 0.2)) { reminders.openBanner() } },
                    onDismiss: { withAnimation(.easeOut(duration: 0.2)) { reminders.dismissBanner() } }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .sensoryFeedback(.success, trigger: reminder.key)
            }
            Spacer(minLength: 0)
        }
        .animation(.spring(duration: 0.3), value: reminders.banner?.key)
    }
}

private struct MeetingReminderBanner: View {
    let reminder: MeetingReminder
    let onOpen: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 15)) { context in
            HStack(alignment: .center, spacing: Spacing.sm) {
                Button(action: onOpen) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "person.wave.2.fill")
                            .font(.title2)
                            .foregroundStyle(Palette.brandPrimary)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(reminder.title(at: context.date))
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                                .lineLimit(2)
                            if !reminder.speakingTopic.isEmpty {
                                Text(reminder.speakingTopic)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.85))
                                    .lineLimit(2)
                            }
                            Text(MeetingReminder.joinHint)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Palette.brandPrimary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("reminder.banner")

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: Metrics.minimumTapTarget, height: Metrics.minimumTapTarget)
                }
                .accessibilityLabel("Dismiss reminder")
            }
            .padding(.leading, 14)
            .padding(.vertical, Spacing.sm)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.black.opacity(0.92)))
            .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
            .padding(.horizontal, Spacing.sm)
            .padding(.top, Spacing.xs)
        }
    }
}

extension View {
    /// Explains speaker reminders once, then asks for notification permission if the user agrees.
    func notificationPermissionPrompt(_ reminders: MeetingReminderCenter) -> some View {
        modifier(NotificationPermissionPrompt(reminders: reminders))
    }
}

private struct NotificationPermissionPrompt: ViewModifier {
    let reminders: MeetingReminderCenter

    func body(content: Content) -> some View {
        content
            .task { await reminders.refreshPermissionPrompt() }
            .alert(
                "Get speaker reminders",
                isPresented: Binding(
                    get: { reminders.shouldExplainPermission },
                    set: { _ in }
                )
            ) {
                Button("Allow notifications") {
                    Task { await reminders.answerPermissionPrompt(allow: true) }
                }
                Button("Not now", role: .cancel) {
                    Task { await reminders.answerPermissionPrompt(allow: false) }
                }
            } message: {
                Text("Tatum Tech notifies you 2 minutes before each virtual speaker session starts, so you can join on time. Allow notifications to get these reminders when the app is closed.")
            }
    }
}
