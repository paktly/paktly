import UIKit
import UserNotifications

extension Notification.Name {
    static let paktlyDidReceiveDeviceToken = Notification.Name("io.paktly.didReceiveDeviceToken")
    static let paktlyDidOpenRemoteNotification = Notification.Name("io.paktly.didOpenRemoteNotification")
}

final class PaktlyAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        NotificationCenter.default.post(name: .paktlyDidReceiveDeviceToken, object: deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        PushNotificationService.shared.recordRegistrationFailure(error)
    }
}

@MainActor
final class PushNotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = PushNotificationService()

    enum AuthorizationState: Equatable { case unknown, denied, authorized, provisional }
    @Published private(set) var authorizationState: AuthorizationState = .unknown
    @Published private(set) var registrationError: String?

    private let center = UNUserNotificationCenter.current()
    private let installationKey = "io.paktly.push-installation-id"
    private let tokenKey = "io.paktly.push-token"
    private var tokenObserver: NSObjectProtocol?

    private override init() {
        super.init()
        center.delegate = self
        configureCategories()
        tokenObserver = NotificationCenter.default.addObserver(
            forName: .paktlyDidReceiveDeviceToken,
            object: nil,
            queue: .main
        ) { notification in
            guard let token = notification.object as? Data else { return }
            Task { @MainActor in await PushNotificationService.shared.register(token: token) }
        }
    }

    func refreshAuthorizationState() async {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .ephemeral: authorizationState = .authorized
        case .provisional: authorizationState = .provisional
        case .denied: authorizationState = .denied
        case .notDetermined: authorizationState = .unknown
        @unknown default: authorizationState = .unknown
        }
    }

    func requestAuthorization() async {
        registrationError = nil
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            await refreshAuthorizationState()
            if granted { UIApplication.shared.registerForRemoteNotifications() }
        } catch {
            registrationError = "Notifications could not be enabled. You can try again from Settings."
        }
    }

    func activateIfAuthorized() async {
        await refreshAuthorizationState()
        guard authorizationState == .authorized || authorizationState == .provisional else { return }
        UIApplication.shared.registerForRemoteNotifications()
        if let token = UserDefaults.standard.string(forKey: tokenKey) {
            try? await APIClient.shared.registerPushDevice(
                installationId: installationId,
                token: token,
                environment: apnsEnvironment
            )
        }
    }

    func unregister() async {
        try? await APIClient.shared.unregisterPushDevice(installationId: installationId)
        try? await center.setBadgeCount(0)
    }

    func recordRegistrationFailure(_ error: Error) {
        registrationError = "This device could not register for notifications."
    }

    private func register(token data: Data) async {
        let token = data.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(token, forKey: tokenKey)
        guard KeychainTokenStore.load() != nil else { return }
        do {
            try await APIClient.shared.registerPushDevice(
                installationId: installationId,
                token: token,
                environment: apnsEnvironment
            )
            registrationError = nil
        } catch {
            registrationError = "Paktly could not finish notification setup. Pull to refresh and try again."
        }
    }

    private var installationId: String {
        if let value = UserDefaults.standard.string(forKey: installationKey), UUID(uuidString: value) != nil { return value }
        let value = UUID().uuidString.lowercased()
        UserDefaults.standard.set(value, forKey: installationKey)
        return value
    }

    private var apnsEnvironment: String {
        (Bundle.main.object(forInfoDictionaryKey: "PaktlyAPNSEnvironment") as? String) ?? "SANDBOX"
    }

    private func configureCategories() {
        let review = UNNotificationAction(identifier: "REVIEW_INVITATION", title: "Review", options: [.foreground])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: "INVITATION", actions: [review], intentIdentifiers: [])
        ])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound, .badge]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let payload = response.notification.request.content.userInfo
        await MainActor.run {
            NotificationCenter.default.post(name: .paktlyDidOpenRemoteNotification, object: payload)
        }
    }
}
