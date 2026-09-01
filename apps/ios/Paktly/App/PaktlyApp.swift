import GoogleSignIn
import SwiftUI

@main
struct PaktlyApp: App {
    @UIApplicationDelegateAdaptor(PaktlyAppDelegate.self) private var appDelegate
    @StateObject private var session = AppSession(
        smartAccountService: SocketFiNativeSmartAccountService()
    )
    @StateObject private var model = AppModel()
    @StateObject private var pushNotifications = PushNotificationService.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(model)
                .environmentObject(pushNotifications)
                .tint(PaktlyColor.forest)
                .onOpenURL { url in
                    if !GIDSignIn.sharedInstance.handle(url) {
                        model.handleIncomingURL(url)
                    }
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    if let url = activity.webpageURL {
                        model.handleIncomingURL(url)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .paktlyDidOpenRemoteNotification)) { notification in
                    if let payload = notification.object as? [AnyHashable: Any] {
                        model.handleRemoteNotification(payload)
                    }
                }
        }
    }
}
