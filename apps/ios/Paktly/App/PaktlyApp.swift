import GoogleSignIn
import SwiftUI

@main
struct PaktlyApp: App {
    @StateObject private var session = AppSession(
        smartAccountService: SocketFiNativeSmartAccountService()
    )
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(model)
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
        }
    }
}
