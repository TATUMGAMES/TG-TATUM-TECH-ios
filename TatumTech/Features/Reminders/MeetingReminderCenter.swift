import Foundation
import Observation
import OSLog
import TatumTechKit
import UserNotifications

/// Where a reminder leads: the event's virtual speakers, scrolled to the speaker.
struct ReminderDestination: Equatable, Sendable {
    let eventID: String
    let speakerID: String
}

/// Reminds the user two minutes before each virtual speaker session.
///
/// Reminders are scheduled as local notifications. While the app is in the foreground a due
/// reminder appears as an in-app banner instead of a system notification. Each reminder is
/// delivered once; delivered keys are remembered for a day after the session ends.
@MainActor
@Observable
final class MeetingReminderCenter: NSObject {
    static let debugReminderDelay: TimeInterval = 10

    /// The reminder shown in the in-app banner, if any.
    private(set) var banner: MeetingReminder?
    /// A destination opened from a notification or banner, waiting to be shown.
    var pendingDestination: ReminderDestination?
    /// Whether to explain reminders before asking for notification permission.
    private(set) var shouldExplainPermission = false

    private let notifications: UNUserNotificationCenter?
    private let defaults: UserDefaults
    private let stateKey = "tatumTech.meetingReminders"
    private let logger = Logger(subsystem: AppLog.subsystem, category: "Reminders")
    private var state: MeetingReminderState

    /// `notifications` is `nil` in UI tests, where nothing is scheduled.
    init(notifications: UNUserNotificationCenter?, defaults: UserDefaults = .standard) {
        self.notifications = notifications
        self.defaults = defaults
        if let data = defaults.data(forKey: stateKey),
           let saved = try? JSONDecoder().decode(MeetingReminderState.self, from: data) {
            state = saved
        } else {
            state = MeetingReminderState()
        }
        super.init()
        notifications?.delegate = self
    }

    // MARK: Scheduling

    /// Schedules reminders for every upcoming speaker session in `events` and cancels ones that
    /// are no longer listed.
    func sync(events: [Event]) async {
        guard let notifications else { return }
        await reconcileDelivered()
        let now = Date()
        let plan = MeetingReminderPlanner.plan(events: events, state: &state, now: now)
        save()
        if !plan.cancelledKeys.isEmpty {
            notifications.removePendingNotificationRequests(withIdentifiers: Array(plan.cancelledKeys))
        }
        for item in plan.scheduled {
            if item.delay < 1 {
                deliverNow(item.reminder, now: now)
            } else {
                await schedule(item.reminder, after: item.delay)
            }
        }
    }

    /// Debug builds: a reminder for `speaker` in ten seconds.
    func scheduleTestReminder(eventID: String, speaker: Speaker) async {
        let reminder = MeetingReminderPlanner.testReminder(
            eventID: eventID, eventName: nil, speaker: speaker, delay: Self.debugReminderDelay, now: Date()
        )
        await schedule(reminder, after: Self.debugReminderDelay)
    }

    private func schedule(_ reminder: MeetingReminder, after delay: TimeInterval) async {
        guard let notifications else { return }
        let content = Self.content(for: reminder, at: reminder.triggerDate)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false)
        do {
            try await notifications.add(UNNotificationRequest(identifier: reminder.key, content: content, trigger: trigger))
        } catch {
            logger.error("Could not schedule reminder: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// A reminder whose time has already come (for example after the app was closed).
    private func deliverNow(_ reminder: MeetingReminder, now: Date) {
        switch MeetingReminderDelivery.decide(reminder, state: &state, isForeground: true, now: now) {
        case .banner:
            save()
            show(reminder)
        case .notification, .alreadyDelivered, .ended:
            break
        }
    }

    /// Marks notifications the system delivered while the app was away, and removes ones whose
    /// session has ended.
    private func reconcileDelivered() async {
        guard let notifications else { return }
        let delivered = await notifications.deliveredNotifications()
        let now = Date()
        var expired: [String] = []
        for notification in delivered {
            guard let reminder = Self.reminder(from: notification.request.content.userInfo) else { continue }
            _ = state.markFired(reminder.key, end: reminder.end)
            if reminder.hasEnded(at: now) { expired.append(notification.request.identifier) }
        }
        save()
        if !expired.isEmpty { notifications.removeDeliveredNotifications(withIdentifiers: expired) }
    }

    // MARK: Banner

    private func show(_ reminder: MeetingReminder) {
        banner = reminder
    }

    func dismissBanner() {
        banner = nil
    }

    func openBanner() {
        guard let banner else { return }
        pendingDestination = ReminderDestination(eventID: banner.eventID, speakerID: banner.speakerID)
        self.banner = nil
    }

    // MARK: Permission

    /// Shows the explanation once, before the system permission request.
    func refreshPermissionPrompt() async {
        guard let notifications, !state.notificationPermissionRequested else {
            shouldExplainPermission = false
            return
        }
        let settings = await notifications.notificationSettings()
        shouldExplainPermission = settings.authorizationStatus == .notDetermined
    }

    func answerPermissionPrompt(allow: Bool) async {
        state.notificationPermissionRequested = true
        save()
        shouldExplainPermission = false
        guard allow, let notifications else { return }
        do {
            _ = try await notifications.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            logger.error("Notification authorization failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: Account deletion

    func removeAll() {
        notifications?.removeAllPendingNotificationRequests()
        notifications?.removeAllDeliveredNotifications()
        banner = nil
        pendingDestination = nil
        let requested = state.notificationPermissionRequested
        state = MeetingReminderState(notificationPermissionRequested: requested)
        save()
    }

    // MARK: Delivery callbacks

    fileprivate func willPresent(_ reminder: MeetingReminder) {
        switch MeetingReminderDelivery.decide(reminder, state: &state, isForeground: true, now: Date()) {
        case .banner:
            save()
            show(reminder)
        case .notification, .alreadyDelivered, .ended:
            break
        }
    }

    fileprivate func didOpen(_ reminder: MeetingReminder) {
        _ = state.markFired(reminder.key, end: reminder.end)
        save()
        pendingDestination = ReminderDestination(eventID: reminder.eventID, speakerID: reminder.speakerID)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: stateKey)
        }
    }

    // MARK: Notification payload

    private enum Key {
        static let key = "reminderKey", eventID = "eventID", eventName = "eventName"
        static let speakerID = "speakerID", speakerName = "speakerName", topic = "topic"
        static let start = "start", end = "end"
    }

    private static func content(for reminder: MeetingReminder, at date: Date) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = reminder.title(at: date)
        content.body = reminder.body
        if let eventName = reminder.eventName { content.subtitle = eventName }
        content.sound = .default
        content.threadIdentifier = "virtual_speakers"
        var info: [String: Any] = [
            Key.key: reminder.key,
            Key.eventID: reminder.eventID,
            Key.speakerID: reminder.speakerID,
            Key.speakerName: reminder.speakerName,
            Key.topic: reminder.speakingTopic,
            Key.start: reminder.start.timeIntervalSince1970,
            Key.end: reminder.end.timeIntervalSince1970
        ]
        if let eventName = reminder.eventName { info[Key.eventName] = eventName }
        content.userInfo = info
        return content
    }

    nonisolated static func reminder(from info: [AnyHashable: Any]) -> MeetingReminder? {
        guard let key = info[Key.key] as? String,
              let eventID = info[Key.eventID] as? String,
              let speakerID = info[Key.speakerID] as? String,
              let start = info[Key.start] as? TimeInterval,
              let end = info[Key.end] as? TimeInterval
        else { return nil }
        return MeetingReminder(
            key: key,
            eventID: eventID,
            eventName: info[Key.eventName] as? String,
            speakerID: speakerID,
            speakerName: info[Key.speakerName] as? String ?? "",
            speakingTopic: info[Key.topic] as? String ?? "",
            start: Date(timeIntervalSince1970: start),
            end: Date(timeIntervalSince1970: end)
        )
    }
}

extension MeetingReminderCenter: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        guard let reminder = Self.reminder(from: notification.request.content.userInfo) else { return [.banner, .sound] }
        await willPresent(reminder)
        return []
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let reminder = Self.reminder(from: response.notification.request.content.userInfo) else { return }
        await didOpen(reminder)
    }
}
