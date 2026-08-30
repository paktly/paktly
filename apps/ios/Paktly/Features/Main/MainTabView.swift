import SwiftUI

private enum PaktlyTab: String, CaseIterable {
    case home, plans, activity, balances, profile

    var title: String {
        switch self {
        case .home: "Home"
        case .plans: "Plans"
        case .activity: "Activity"
        case .balances: "Balances"
        case .profile: "You"
        }
    }

    var icon: String {
        switch self {
        case .home: "house"
        case .plans: "square.stack.3d.up"
        case .activity: "bell"
        case .balances: "creditcard"
        case .profile: "person"
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selection: PaktlyTab = .home

    var body: some View {
        TabView(selection: $selection) {
            HomeView().tag(PaktlyTab.home)
            GroupsView().tag(PaktlyTab.plans)
            ActivityView().tag(PaktlyTab.activity)
            BalancesOverviewView().tag(PaktlyTab.balances)
            ProfileView().tag(PaktlyTab.profile)
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) { tabBar }
        .task { await model.refresh() }
    }

    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(PaktlyTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { selection = tab }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: selection == tab ? "\(tab.icon).fill" : tab.icon)
                            .font(.system(size: 17, weight: .semibold))
                            .frame(height: 20)
                        Text(tab.title)
                            .font(.system(size: 10, weight: selection == tab ? .bold : .medium))
                    }
                    .foregroundStyle(selection == tab ? PaktlyColor.forest : PaktlyColor.secondaryInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background {
                        if selection == tab {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(PaktlyColor.mint.opacity(0.28))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
        }
        .shadow(color: Color.black.opacity(0.12), radius: 20, y: 8)
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}
