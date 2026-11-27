import AppKit
import UserNotifications

/// macOS notifications ("Claude закончил", "Claude ждёт ответа") and what happens on a click.
///
/// The system asks the user for permission once, on the first notification. Clicking a notification brings the
/// app forward and opens that session (`onOpenSession`).
@MainActor
final class Notifier: NSObject {
    var onOpenSession: ((UUID) -> Void)?

    private let center = UNUserNotificationCenter.current()
    private var askedForPermission = false

    override init() {
        super.init()
        center.delegate = self
    }

    func post(title: String, body: String, sessionID: UUID) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["sessionID": sessionID.uuidString]
        // One notification per session: a newer one replaces the previous instead of piling up.
        let request = UNNotificationRequest(identifier: sessionID.uuidString, content: content, trigger: nil)

        let center = center
        if askedForPermission {
            center.add(request)
        } else {
            askedForPermission = true
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                if granted { center.add(request) }
            }
        }
    }

    /// The session got looked at: its notification in Notification Center is no longer news.
    func withdraw(sessionID: UUID) {
        center.removeDeliveredNotifications(withIdentifiers: [sessionID.uuidString])
    }
}

extension Notifier: UNUserNotificationCenterDelegate {
    /// Show the banner even when the app is in front (we only post for sessions that aren't on screen).
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let raw = response.notification.request.content.userInfo["sessionID"] as? String,
              let id = UUID(uuidString: raw) else { return }
        await MainActor.run {
            NSApp.activate()
            onOpenSession?(id)
        }
    }
}
