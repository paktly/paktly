import SwiftUI

struct GroupDetailView: View {
    @EnvironmentObject private var model: AppModel
    let groupID: String
    @State private var group: APIGroup?; @State private var members: [APIGroupMember] = []; @State private var expenses: [APIExpense] = []
    @State private var balances: [APIBalance] = []; @State private var suggestions: [APISuggestedSettlement] = []
    @State private var showingExpense = false; @State private var editing: APIExpense?; @State private var inviting = false; @State private var error: String?
    var body: some View {
        List {
            if let error { Text(error).foregroundStyle(.red) }
            Section("Balances") {
                ForEach(balances) { balance in HStack { Text(balance.displayName); Spacer(); Text(Double(balance.netMinor) / 100, format: .currency(code: group?.defaultCurrency ?? "USD").precision(.fractionLength(2))).foregroundStyle(balance.netMinor >= 0 ? PaktlyColor.forest : PaktlyColor.coral) } }
                ForEach(Array(suggestions.enumerated()), id: \.offset) { _, suggestion in Button("Record suggested settlement") { Task { try? await model.client.settle(groupID: groupID, from: suggestion.fromUserId, to: suggestion.toUserId, amountMinor: suggestion.amountMinor); await load() } } }
            }
            Section("Expenses") {
                if expenses.isEmpty {
                    Text("Nothing spent yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(expenses) { expense in
                    Button {
                        editing = expense
                        showingExpense = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(expense.description)
                                    .foregroundStyle(.primary)
                                Text("Paid by \(expense.payerName ?? "member") · \(expense.splitMethod.capitalized)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(
                                Double(expense.originalAmountMinor) / 100,
                                format: .currency(code: expense.originalCurrency)
                            )
                        }
                    }
                }
                .onDelete { offsets in
                    Task {
                        for index in offsets {
                            try? await model.client.deleteExpense(id: expenses[index].id)
                        }
                        await load()
                    }
                }
            }
            Section("Members") { ForEach(members) { member in HStack { Text(member.displayName); Spacer(); Text(member.role.capitalized).font(.caption).foregroundStyle(.secondary) } }; Button("Invite member") { inviting = true } }
        }
        .navigationTitle(group?.name ?? "Plan")
        .toolbar { Button("Add expense", systemImage: "plus") { editing = nil; showingExpense = true } }
        .sheet(isPresented: $showingExpense) { ExpenseEditorView(groupID: groupID, currency: group?.defaultCurrency ?? "USD", members: members, existing: editing) { await load() } }
        .sheet(isPresented: $inviting) { InviteView(groupID: groupID) }
        .task { await load() }
        .refreshable { await load() }
    }
    private func load() async {
        do { async let details = model.client.group(groupID); async let expenseList = model.client.expenses(groupID: groupID); async let balanceData = model.client.balances(groupID: groupID); let d = try await details; group = d.0; members = d.1; expenses = try await expenseList; let b = try await balanceData; balances = b.0; suggestions = b.1; error = nil } catch { self.error = "We couldn’t load this plan." }
    }
}

private struct InviteView: View {
    @EnvironmentObject private var model: AppModel; @Environment(\.dismiss) private var dismiss
    let groupID: String; @State private var email = ""; @State private var developmentToken: String?
    var body: some View { NavigationStack { Form { TextField("friend@example.com", text: $email).textInputAutocapitalization(.never).keyboardType(.emailAddress); if let developmentToken { Section("Local testing code") { Text(developmentToken).textSelection(.enabled); ShareLink(item: developmentToken) } } }.navigationTitle("Invite member").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Send") { Task { developmentToken = try? await model.client.invite(groupID: groupID, email: email) } }.disabled(!email.contains("@")) } } } }
}
