import SwiftUI

struct ExpenseEditorView: View {
    enum Method: String, CaseIterable, Identifiable { case equal = "EQUAL", exact = "EXACT", percentage = "PERCENTAGE", shares = "SHARES", itemized = "ITEMIZED"; var id: String { rawValue }; var title: String { rawValue.capitalized } }
    @EnvironmentObject private var model: AppModel; @Environment(\.dismiss) private var dismiss
    let groupID: String; let currency: String; let members: [APIGroupMember]; let existing: APIExpense?; let completed: () async -> Void
    @State private var description = ""; @State private var amount = ""; @State private var category = "Food"; @State private var payer = ""; @State private var method = Method.equal
    @State private var expenseCurrency = ""; @State private var exchangeRate = ""
    @State private var selected = Set<String>(); @State private var values: [String: String] = [:]; @State private var saving = false; @State private var errorMessage: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("Expense") { TextField("What was it?", text: $description); TextField("0.00", text: $amount).keyboardType(.decimalPad); TextField("Currency", text: $expenseCurrency).textInputAutocapitalization(.characters); if expenseCurrency.uppercased() != currency { TextField("1 \(expenseCurrency.uppercased()) equals how many \(currency)?", text: $exchangeRate).keyboardType(.decimalPad); Text("This rate is locked to the expense and will not change later.").font(.caption).foregroundStyle(.secondary) }; Picker("Category", selection: $category) { ForEach(["Accommodation","Flights","Transportation","Food","Drinks","Activities","Shopping","Groceries","Tickets","Fuel","Fees","Other"], id: \.self) { Text($0) } }; Picker("Paid by", selection: $payer) { ForEach(members) { Text($0.displayName).tag($0.id) } } }
                Section("Split") {
                    Picker("Method", selection: $method) { ForEach(Method.allCases) { Text($0.title).tag($0) } }
                    ForEach(members) { member in HStack { Toggle(member.displayName, isOn: Binding(get: { selected.contains(member.id) }, set: { if $0 { selected.insert(member.id) } else { selected.remove(member.id) } })); if method != .equal { TextField(unitLabel, text: Binding(get: { values[member.id, default: ""] }, set: { values[member.id] = $0 })).frame(width: 80).keyboardType(.decimalPad).disabled(!selected.contains(member.id)) } } }
                    if method == .percentage { Text("Percentages must add up to 100.").font(.caption).foregroundStyle(.secondary) }
                    if method == .itemized { Text("Enter each member’s item total. Shared tax and tip can be added as separate items in a later edit.").font(.caption).foregroundStyle(.secondary) }
                }
                if let errorMessage { Section { Text(errorMessage).foregroundStyle(.red) } }
            }
            .navigationTitle(existing == nil ? "Add expense" : "Edit expense")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await save() } }.disabled(!valid || saving) } }
            .onAppear { configure() }
        }
    }
    private var unitLabel: String { method == .percentage ? "%" : method == .shares ? "shares" : currency }
    private var minorAmount: Int? { guard let number = Decimal(string: amount) else { return nil }; return NSDecimalNumber(decimal: number * 100).intValue }
    private var valid: Bool {
        guard !description.isEmpty, let total = minorAmount, total > 0, expenseCurrency.count == 3, !payer.isEmpty, !selected.isEmpty else { return false }
        if expenseCurrency.uppercased() != currency && (Decimal(string: exchangeRate) ?? 0) <= 0 { return false }
        let chosen = members.map(\.id).filter(selected.contains)
        switch method {
        case .equal: return true
        case .exact, .itemized: return chosen.reduce(0) { $0 + moneyMinor(values[$1]) } == total
        case .percentage: return chosen.reduce(0) { $0 + percentageBasisPoints(values[$1]) } == 10_000
        case .shares: return chosen.allSatisfy { (Int(values[$0] ?? "") ?? 0) > 0 }
        }
    }
    private func configure() {
        guard payer.isEmpty else { return }; payer = existing?.paidBy ?? members.first?.id ?? ""; selected = Set(members.map(\.id)); expenseCurrency = existing?.originalCurrency ?? currency
        if let existing { description = existing.description; amount = String(format: "%.2f", Double(existing.originalAmountMinor) / 100); category = existing.category; method = Method(rawValue: existing.splitMethod) ?? .equal }
    }
    private func save() async {
        guard let minorAmount else { return }; saving = true
        let ids = members.map(\.id).filter(selected.contains)
        let split: ExpenseDraft.Split
        switch method {
        case .equal: split = .init(method: method.rawValue, participantIds: ids, shares: nil, items: nil)
        case .exact: split = .init(method: method.rawValue, participantIds: nil, shares: ids.map { .init(userId: $0, value: moneyMinor(values[$0])) }, items: nil)
        case .percentage: split = .init(method: method.rawValue, participantIds: nil, shares: ids.map { .init(userId: $0, value: percentageBasisPoints(values[$0])) }, items: nil)
        case .shares: split = .init(method: method.rawValue, participantIds: nil, shares: ids.map { .init(userId: $0, value: Int(values[$0] ?? "") ?? 0) }, items: nil)
        case .itemized: split = .init(method: method.rawValue, participantIds: nil, shares: nil, items: ids.map { .init(amountMinor: moneyMinor(values[$0]), participantIds: [$0]) })
        }
        var lockedRate: ExpenseDraft.ExchangeRate?
        if expenseCurrency.uppercased() != currency, let decimal = Decimal(string: exchangeRate) {
            lockedRate = .init(numerator: NSDecimalNumber(decimal: decimal * 1_000_000).intValue, denominator: 1_000_000, provider: "USER_LOCKED", timestamp: .now)
        }
        let draft = ExpenseDraft(clientOperationId: UUID().uuidString.lowercased(), description: description, category: category, amountMinor: minorAmount, currency: expenseCurrency.uppercased(), paidBy: payer, expenseDate: existing?.expenseDate ?? .now, notes: nil, split: split, exchangeRate: lockedRate)
        do {
            if let existing { try await model.client.updateExpense(id: existing.id, expectedVersion: existing.currentVersion, draft: draft) }
            else if !(await model.submitExpense(groupID: groupID, draft: draft)) { throw APIError.requestFailed(400) }
            await completed(); dismiss()
        } catch { saving = false; errorMessage = "We couldn’t save this expense. Review the split and try again." }
    }
    private func moneyMinor(_ value: String?) -> Int { guard let value, let decimal = Decimal(string: value) else { return 0 }; return NSDecimalNumber(decimal: decimal * 100).intValue }
    private func percentageBasisPoints(_ value: String?) -> Int { guard let value, let decimal = Decimal(string: value) else { return 0 }; return NSDecimalNumber(decimal: decimal * 100).intValue }
}
