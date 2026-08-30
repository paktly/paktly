import SwiftUI

@main
struct PaktlyApp: App {
    @StateObject private var session = AppSession(
        smartAccountService: PreviewSmartAccountService()
    )
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(model)
                .tint(PaktlyColor.forest)
        }
    }
}
