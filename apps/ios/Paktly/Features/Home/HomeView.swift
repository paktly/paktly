import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel

    private var firstName: String {
        model.currentUser?.displayName.split(separator: " ").first.map(String.init) ?? "there"
    }

    private var netMinor: Int { model.youAreOwedMinor - model.youOweMinor }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 22) {
                    header
                    moneyOverview
                    if !model.invitations.isEmpty { invitationsSection }
                    plansSection
                    statusSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
            .background(PaktlyColor.background.ignoresSafeArea())
            .refreshable { await model.refresh() }
            .navigationBarHidden(true)
            .navigationDestination(for: String.self) { id in GroupDetailView(groupID: id) }
        }
    }

    private var invitationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PaktlySectionHeader(title: model.invitations.count == 1 ? "Plan invitation" : "Plan invitations")
            ForEach(model.invitations.prefix(2)) { invitation in
                PaktlyInvitationCard(invitation: invitation) { model.presentInvitation(invitation) }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(greeting), \(firstName)")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(PaktlyColor.ink)
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.subheadline)
                    .foregroundStyle(PaktlyColor.secondaryInk)
            }
            Spacer()
            PaktlyAvatar(name: firstName, size: 46)
        }
    }

    private var moneyOverview: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("YOUR POSITION")
                        .font(.caption2.weight(.bold))
                        .tracking(1.4)
                        .foregroundStyle(Color.white.opacity(0.7))
                    Text(netMinor == 0 ? "All settled" : money(abs(netMinor)))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(netMinor > 0 ? "Overall, you’re owed" : netMinor < 0 ? "Overall, you owe" : "Nothing outstanding right now")
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.72))
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(PaktlyColor.forest)
                    .padding(11)
                    .background(.white, in: Circle())
            }

            HStack(spacing: 0) {
                balanceMetric("You owe", model.youOweMinor, tint: PaktlyColor.coral)
                Rectangle().fill(Color.white.opacity(0.18)).frame(width: 1, height: 40)
                balanceMetric("You’re owed", model.youAreOwedMinor, tint: PaktlyColor.mint)
            }
        }
        .padding(22)
        .background(
            LinearGradient(colors: [PaktlyColor.forest, Color(red: 0.08, green: 0.22, blue: 0.17)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .shadow(color: PaktlyColor.forest.opacity(0.22), radius: 24, y: 12)
    }

    private var plansSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PaktlySectionHeader(title: "Your plans")

            if let group = model.groups.first {
                NavigationLink(value: group.id) {
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(PaktlyColor.lavender.opacity(0.55))
                                .frame(width: 62, height: 62)
                            Image(systemName: "sparkles")
                                .font(.title2.weight(.medium))
                                .foregroundStyle(PaktlyColor.forest)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text(group.name)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(PaktlyColor.ink)
                                .lineLimit(1)
                            Text("\(group.memberCount ?? 1) people · \(group.defaultCurrency)")
                                .font(.subheadline)
                                .foregroundStyle(PaktlyColor.secondaryInk)
                            Text("Open plan")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(PaktlyColor.forest)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(PaktlyColor.secondaryInk.opacity(0.7))
                    }
                    .padding(16)
                    .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                PaktlyEmptyState(title: "Make your first plan", message: "Bring people, costs, and decisions together in one calm space.", icon: "plus")
            }
        }
    }

    @ViewBuilder private var statusSection: some View {
        switch model.state {
        case .loading where model.groups.isEmpty:
            HStack(spacing: 12) {
                ProgressView().tint(PaktlyColor.forest)
                Text("Bringing everything up to date…")
                    .font(.subheadline)
                    .foregroundStyle(PaktlyColor.secondaryInk)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .failed(let message):
            PaktlyStatusBanner(icon: "wifi.exclamationmark", title: "Couldn’t refresh", message: message, tint: PaktlyColor.coral)
        default:
            if model.pendingSyncCount > 0 {
                PaktlyStatusBanner(icon: "arrow.triangle.2.circlepath", title: "\(model.pendingSyncCount) waiting to sync", message: "Saved safely on this device. We’ll retry automatically.", tint: PaktlyColor.lavender)
            } else {
                PaktlyStatusBanner(icon: "checkmark.shield.fill", title: "Everything is up to date", message: "Your shared activity has been synced.", tint: PaktlyColor.mint)
            }
        }
    }

    private func balanceMetric(_ title: String, _ amount: Int, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(Color.white.opacity(0.68))
            Text(money(amount)).font(.headline.weight(.bold)).foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, title == "You’re owed" ? 18 : 0)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        return hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"
    }

    private func money(_ minor: Int) -> String {
        (Double(minor) / 100).formatted(.currency(code: model.dashboardCurrency))
    }
}
