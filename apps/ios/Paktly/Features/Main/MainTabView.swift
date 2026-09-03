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
        .task {
            await model.refresh()
            await PushNotificationService.shared.activateIfAuthorized()
        }
        .sheet(
            item: Binding(
                get: { model.presentedInvitation },
                set: { value in if value == nil { model.dismissInvitation() } }
            )
        ) { presented in
            InvitationDecisionView(invitation: presented.invitation)
                .environmentObject(model)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(
            item: Binding(
                get: { model.presentedPlan },
                set: { value in if value == nil { model.dismissPresentedPlan() } }
            )
        ) { plan in
            NavigationStack { GroupDetailView(groupID: plan.id) }
        }
        .sheet(
            item: Binding(
                get: { model.presentedJoinLink },
                set: { value in if value == nil { model.dismissJoinLink() } }
            )
        ) { link in
            JoinLinkDecisionView(link: link.preview)
                .environmentObject(model)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(PaktlyTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { selection = tab }
                } label: {
                    VStack(spacing: 4) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: selection == tab ? "\(tab.icon).fill" : tab.icon)
                                .font(.system(size: 17, weight: .semibold))
                                .frame(height: 20)
                            if tab == .activity && model.unreadNotificationCount > 0 {
                                Text(model.unreadNotificationCount > 99 ? "99+" : "\(model.unreadNotificationCount)")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 4)
                                    .frame(minWidth: 16, minHeight: 16)
                                    .background(PaktlyColor.coral, in: Capsule())
                                    .offset(x: 12, y: -7)
                            }
                        }
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

private struct JoinLinkDecisionView: View {
    @EnvironmentObject private var model: AppModel
    let link: APIJoinLinkPreview
    @State private var working = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(PaktlyColor.forest)
                    .frame(width: 58, height: 58)
                    .background(PaktlyColor.mint.opacity(0.45), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Join \(link.groupName)?")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(PaktlyColor.ink)
                    Text("Shared by \(link.creatorName) · \(link.memberCount) members")
                        .font(.subheadline)
                        .foregroundStyle(PaktlyColor.secondaryInk)
                    Text("You’ll join as a member. Joining never gives anyone access to your personal account or wallet.")
                        .font(.subheadline)
                        .foregroundStyle(PaktlyColor.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(PaktlyColor.coral)
                }

                Spacer(minLength: 0)
                Button {
                    Task { await join() }
                } label: {
                    HStack(spacing: 8) {
                        if working { ProgressView().tint(PaktlyColor.background) }
                        Text(working ? "Joining…" : "Join plan")
                    }
                }
                .buttonStyle(PaktlyPrimaryButtonStyle())
                .disabled(working)
            }
            .padding(24)
            .background(PaktlyColor.background.ignoresSafeArea())
            .navigationTitle("Plan invitation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { model.dismissJoinLink() }
                }
            }
        }
    }

    private func join() async {
        working = true
        errorMessage = nil
        do {
            try await model.acceptPresentedJoinLink()
        } catch {
            errorMessage = "This invite link could not be accepted. Ask the organizer for a new one."
            working = false
        }
    }
}

private struct InvitationDecisionView: View {
    @EnvironmentObject private var model: AppModel
    let invitation: APIInvitation
    @State private var working = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "person.2.badge.plus")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(PaktlyColor.forest)
                    .frame(width: 58, height: 58)
                    .background(PaktlyColor.mint.opacity(0.45), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text("You’re invited")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(PaktlyColor.ink)
                    Text("\(invitation.inviterName) invited you to join \(invitation.groupName).")
                        .font(.body)
                        .foregroundStyle(PaktlyColor.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Expires \(invitation.expiresAt, style: .relative)")
                        .font(.caption)
                        .foregroundStyle(PaktlyColor.secondaryInk)
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(PaktlyColor.coral)
                }

                Spacer(minLength: 0)

                HStack(spacing: 12) {
                    Button("Decline", role: .destructive) {
                        Task { await decide(accept: false) }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)

                    Button {
                        Task { await decide(accept: true) }
                    } label: {
                        HStack(spacing: 8) {
                            if working { ProgressView().tint(PaktlyColor.background) }
                            Text("Accept invitation")
                        }
                    }
                    .buttonStyle(PaktlyPrimaryButtonStyle())
                }
                .disabled(working)
            }
            .padding(24)
            .background(PaktlyColor.background.ignoresSafeArea())
            .navigationTitle(invitation.groupName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { model.dismissInvitation() }
                }
            }
        }
    }

    private func decide(accept: Bool) async {
        guard !working else { return }
        working = true
        errorMessage = nil
        do {
            if accept {
                try await model.acceptPresentedInvitation()
            } else {
                try await model.declinePresentedInvitation()
            }
        } catch {
            errorMessage = "This invitation could not be updated. Please try again."
            working = false
        }
    }
}
