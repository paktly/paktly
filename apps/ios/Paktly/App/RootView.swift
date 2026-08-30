import SwiftUI

struct RootView: View {
    @EnvironmentObject private var session: AppSession

    var body: some View {
        Group {
            switch session.state {
            case .signedIn:
                MainTabView()
            case .signedOut, .authenticating, .failed:
                WelcomeView()
            }
        }
        .animation(.easeInOut(duration: 0.24), value: session.state)
    }
}
