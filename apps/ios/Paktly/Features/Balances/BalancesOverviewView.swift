import SwiftUI

struct BalancesOverviewView: View {
    @EnvironmentObject private var model: AppModel
    @State private var balances: [(APIGroup, [APIBalance])] = []
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 18) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Balances")
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                .foregroundStyle(PaktlyColor.ink)
                            Text("A clear view of what comes in and goes out.")
                                .font(.subheadline)
                                .foregroundStyle(PaktlyColor.secondaryInk)
                        }
                        Spacer()
                    }

                    summaryCard

                    if balances.isEmpty {
                        PaktlyEmptyState(
                            title: "All settled",
                            message: "Your balances across shared plans will appear here.",
                            icon: "checkmark.seal.fill"
                        )
                    } else {
                        ForEach(balances.indices, id: \.self) { index in
                            let group = balances[index].0
                            let rows = balances[index].1.filter { $0.netMinor != 0 }

                            PaktlyPanel {
                                VStack(alignment: .leading, spacing: 14) {
                                    HStack {
                                        Text(group.name)
                                            .font(.headline)
                                            .foregroundStyle(PaktlyColor.ink)
                                        Spacer()
                                        Text(group.defaultCurrency)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(PaktlyColor.secondaryInk)
                                    }

                                    if rows.isEmpty {
                                        Text("No outstanding balances in this plan.")
                                            .font(.subheadline)
                                            .foregroundStyle(PaktlyColor.secondaryInk)
                                    } else {
                                        ForEach(rows) { balance in
                                            HStack {
                                                PaktlyAvatar(name: balance.displayName, size: 36)
                                                Text(balance.displayName).font(.subheadline.weight(.medium)).foregroundStyle(PaktlyColor.ink)
                                                Spacer()
                                                Text(Double(balance.netMinor) / 100, format: .currency(code: group.defaultCurrency))
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(balance.netMinor >= 0 ? PaktlyColor.forest : PaktlyColor.coral)
                                            }
                                            .padding(.vertical, 8)

                                            if balance.id != rows.last?.id {
                                                Divider()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
            .background(PaktlyColor.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .task { await load() }
            .refreshable { await load() }
        }
    }
    private var summaryCard: some View {
        HStack(spacing: 0) {
            summaryMetric("You owe", model.youOweMinor, PaktlyColor.coral)
            Divider().frame(height: 46)
            summaryMetric("You’re owed", model.youAreOwedMinor, PaktlyColor.forest)
        }
        .padding(20)
        .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func summaryMetric(_ title: String, _ minor: Int, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption).foregroundStyle(PaktlyColor.secondaryInk)
            Text(Double(minor) / 100, format: .currency(code: model.dashboardCurrency))
                .font(.title3.weight(.bold)).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, title == "You’re owed" ? 18 : 0)
    }
    private func load() async { var result: [(APIGroup, [APIBalance])] = []; for group in model.groups { if let data = try? await model.client.balances(groupID: group.id) { result.append((group, data.0)) } }; balances = result }
}
