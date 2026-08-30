import SwiftUI

struct BalancesOverviewView: View {
    @EnvironmentObject private var model: AppModel
    @State private var balances: [(APIGroup, [APIBalance])] = []
    var body: some View {
        NavigationStack {
            List {
                if balances.isEmpty { ContentUnavailableView("All settled", systemImage: "checkmark.circle", description: Text("Your balances across shared plans will appear here.")) }
                ForEach(balances.indices, id: \.self) { index in
                    let group = balances[index].0; let rows = balances[index].1
                    Section(group.name) { ForEach(rows.filter { $0.netMinor != 0 }) { balance in HStack { Text(balance.displayName); Spacer(); Text(Double(balance.netMinor) / 100, format: .currency(code: group.defaultCurrency)).foregroundStyle(balance.netMinor >= 0 ? PaktlyColor.forest : PaktlyColor.coral) } } }
                }
            }.navigationTitle("Balances").task { await load() }.refreshable { await load() }
        }
    }
    private func load() async { var result: [(APIGroup, [APIBalance])] = []; for group in model.groups { if let data = try? await model.client.balances(groupID: group.id) { result.append((group, data.0)) } }; balances = result }
}
