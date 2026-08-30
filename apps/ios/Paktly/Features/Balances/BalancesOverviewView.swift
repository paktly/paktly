import SwiftUI

struct BalancesOverviewView: View {
    @EnvironmentObject private var model: AppModel
    @State private var balances: [(APIGroup, [APIBalance])] = []
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Balances")
                                .font(.largeTitle.weight(.bold))
                                .foregroundStyle(PaktlyColor.ink)
                            Text("Settle up what everyone owes in one place.")
                                .font(.subheadline)
                                .foregroundStyle(PaktlyColor.secondaryInk)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)

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
                                VStack(alignment: .leading, spacing: 10) {
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
                                                Text(balance.displayName)
                                                    .foregroundStyle(PaktlyColor.ink)
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
                .padding(16)
            }
            .background(PaktlyColor.background.ignoresSafeArea())
            .navigationTitle("Balances")
            .task { await load() }
            .refreshable { await load() }
        }
    }
    private func load() async { var result: [(APIGroup, [APIBalance])] = []; for group in model.groups { if let data = try? await model.client.balances(groupID: group.id) { result.append((group, data.0)) } }; balances = result }
}
