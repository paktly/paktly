import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
            GroupsView()
                .tabItem { Label("Plans", systemImage: "person.3.fill") }
            ActivityView()
                .tabItem { Label("Activity", systemImage: "bolt.horizontal.circle.fill") }
            BalancesOverviewView()
                .tabItem { Label("Wallet", systemImage: "wallet.bifold.fill") }
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
        }
        .task { if model.state == .idle { await model.refresh() } }
    }
}
