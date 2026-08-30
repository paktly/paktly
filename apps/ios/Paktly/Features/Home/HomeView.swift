import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Good afternoon, \(model.currentUser?.displayName ?? "there")")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        Text("Everything you share, in one place.")
                            .foregroundStyle(PaktlyColor.secondaryInk)
                    }

                    VStack(alignment: .leading, spacing: 13) {
                        Text("SHARED PLANS")
                            .font(.caption.bold())
                            .tracking(1.4)
                            .foregroundStyle(PaktlyColor.secondaryInk)
                        if let group = model.groups.first {
                            NavigationLink(value: group.id) {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(group.name).font(.title2.bold()).foregroundStyle(PaktlyColor.ink)
                                    Text("\(group.memberCount ?? 1) members · \(group.defaultCurrency)").foregroundStyle(PaktlyColor.secondaryInk)
                                }.frame(maxWidth: .infinity, alignment: .leading).padding(22).background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 24))
                            }
                        } else { Text("Create a plan for a trip, home, event, or anything you share.").foregroundStyle(PaktlyColor.secondaryInk) }
                    }

                    HStack(spacing: 12) {
                        balanceCard(title: "YOU OWE", value: money(model.youOweMinor), color: PaktlyColor.coral)
                        balanceCard(title: "YOU’RE OWED", value: money(model.youAreOwedMinor), color: PaktlyColor.mint)
                    }

                    if model.pendingSyncCount > 0 { VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Pending sync").font(.headline)
                            Spacer()
                            Text("\(model.pendingSyncCount)").foregroundStyle(PaktlyColor.secondaryInk)
                        }
                        HStack {
                            Image(systemName: "arrow.down.to.line.compact")
                                .foregroundStyle(PaktlyColor.forest)
                            Text("Your offline expenses will retry automatically.").font(.subheadline.weight(.semibold))
                        }
                    }
                    .padding(20)
                    .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 22))
                    }
                }
                .padding(20)
            }
            .background(PaktlyColor.background)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Notifications", systemImage: "bell") {}
                        .labelStyle(.iconOnly)
                }
            }
            .navigationDestination(for: String.self) { GroupDetailView(groupID: $0) }
        }
    }

    private func balanceCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.caption2.bold()).tracking(1).foregroundStyle(PaktlyColor.secondaryInk)
            Text(value).font(.system(.title2, design: .rounded, weight: .bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(color.opacity(0.34), in: RoundedRectangle(cornerRadius: 20))
    }

    private func money(_ minor: Int) -> String {
        (Double(minor) / 100).formatted(.currency(code: model.dashboardCurrency))
    }
}
