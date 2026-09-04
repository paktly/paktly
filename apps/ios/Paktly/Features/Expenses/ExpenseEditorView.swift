import SwiftUI

struct ExpensePrefill: Sendable {
    let description: String
    let amount: String
    let currency: String
    let category: String
    let date: Date
    let notes: String?
}

struct ExpenseEditorView: View {
    enum Method: String, CaseIterable, Identifiable { case equal = "EQUAL", exact = "EXACT", percentage = "PERCENTAGE", shares = "SHARES", itemized = "ITEMIZED"; var id: String { rawValue }; var title: String { rawValue.capitalized } }
    @EnvironmentObject private var model: AppModel; @Environment(\.dismiss) private var dismiss
    let groupID: String; let currency: String; let members: [APIGroupMember]; let existing: APIExpense?; let completed: () async -> Void
    @State private var description = ""; @State private var amount = ""; @State private var category = "Food"; @State private var payer = ""; @State private var method = Method.equal
    @State private var expenseCurrency = ""; @State private var exchangeRate = ""
    @State private var expenseDate = Date(); @State private var notes = ""
    @State private var selected = Set<String>(); @State private var values: [String: String] = [:]; @State private var saving = false; @State private var errorMessage: String?
    @State private var showingCurrencyPicker = false; @State private var showingConversion = false
    private let receiptPrefilled: Bool

    init(groupID: String, currency: String, members: [APIGroupMember], existing: APIExpense?, prefill: ExpensePrefill? = nil, completed: @escaping () async -> Void) {
        self.groupID = groupID
        self.currency = currency
        self.members = members
        self.existing = existing
        self.completed = completed
        self.receiptPrefilled = prefill != nil
        _description = State(initialValue: prefill?.description ?? "")
        _amount = State(initialValue: prefill?.amount ?? "")
        _category = State(initialValue: prefill?.category ?? "Food")
        _expenseCurrency = State(initialValue: prefill?.currency ?? "")
        _expenseDate = State(initialValue: prefill?.date ?? existing?.expenseDate ?? .now)
        _notes = State(initialValue: prefill?.notes ?? "")
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Expense") {
                    TextField("What was it?", text: $description)
                    TextField("0.00", text: $amount).keyboardType(.decimalPad)
                    Button { showingCurrencyPicker = true } label: {
                        HStack {
                            Text("Receipt currency").foregroundStyle(.primary)
                            Spacer()
                            Text("\(PaktlyCurrencyCatalog.symbol(for: expenseCurrency))  \(expenseCurrency)").foregroundStyle(PaktlyColor.forest)
                            Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(PaktlyColor.forest)
                        }
                    }
                    if expenseCurrency.uppercased() != currency {
                        Button { showingConversion = true } label: {
                            HStack {
                                Label("Currency conversion", systemImage: "arrow.left.arrow.right")
                                Spacer()
                                Text(exchangeRate.isEmpty ? "Required" : "1 \(expenseCurrency) = \(exchangeRate) \(currency)")
                                    .foregroundStyle(exchangeRate.isEmpty ? PaktlyColor.coral : PaktlyColor.forest)
                            }
                        }
                    }
                    Picker("Category", selection: $category) { ForEach(["Accommodation","Flights","Transportation","Food","Drinks","Activities","Shopping","Groceries","Tickets","Fuel","Fees","Other"], id: \.self) { Text($0) } }
                    DatePicker("Date", selection: $expenseDate, displayedComponents: .date)
                    Picker("Paid by", selection: $payer) { ForEach(members) { Text(payerLabel(for: $0)).tag($0.id) } }.pickerStyle(.menu)
                    TextField("Notes (optional)", text: $notes, axis: .vertical).lineLimit(2...4)
                }
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
            .task {
                guard receiptPrefilled, expenseCurrency.uppercased() != currency else { return }
                try? await Task.sleep(for: .milliseconds(350))
                showingConversion = true
            }
            .onChange(of: expenseCurrency) { oldValue, newValue in
                guard !oldValue.isEmpty, newValue.uppercased() != currency else { return }
                exchangeRate = ""
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(350))
                    showingConversion = true
                }
            }
            .sheet(isPresented: $showingCurrencyPicker) {
                CurrencyPicker(selection: $expenseCurrency)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingConversion) {
                CurrencyConversionView(sourceCurrency: expenseCurrency, planCurrency: currency, amount: amount, rate: $exchangeRate)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
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
        if payer.isEmpty {
            payer = existing?.paidBy ?? model.currentUser?.id ?? members.first?.id ?? ""
        }
        if selected.isEmpty {
            selected = Set(members.map(\.id))
        }
        if expenseCurrency.isEmpty { expenseCurrency = existing?.originalCurrency ?? currency }
        if let existing { description = existing.description; amount = String(format: "%.2f", Double(existing.originalAmountMinor) / 100); category = existing.category; method = Method(rawValue: existing.splitMethod) ?? .equal; expenseDate = existing.expenseDate; notes = existing.notes ?? "" }
    }
    private func payerLabel(for member: APIGroupMember) -> String {
        member.id == model.currentUser?.id ? "You" : member.displayName
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
        let draft = ExpenseDraft(clientOperationId: UUID().uuidString.lowercased(), description: description, category: category, amountMinor: minorAmount, currency: expenseCurrency.uppercased(), paidBy: payer, expenseDate: expenseDate, notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes, split: split, exchangeRate: lockedRate)
        do {
            if let existing { try await model.client.updateExpense(id: existing.id, expectedVersion: existing.currentVersion, draft: draft) }
            else if !(await model.submitExpense(groupID: groupID, draft: draft)) { throw APIError.requestFailed(400) }
            await completed(); dismiss()
        } catch { saving = false; errorMessage = "We couldn’t save this expense. Review the split and try again." }
    }
    private func moneyMinor(_ value: String?) -> Int { guard let value, let decimal = Decimal(string: value) else { return 0 }; return NSDecimalNumber(decimal: decimal * 100).intValue }
    private func percentageBasisPoints(_ value: String?) -> Int { guard let value, let decimal = Decimal(string: value) else { return 0 }; return NSDecimalNumber(decimal: decimal * 100).intValue }
}

private struct CurrencyConversionView: View {
    @Environment(\.dismiss) private var dismiss
    let sourceCurrency: String
    let planCurrency: String
    let amount: String
    @Binding var rate: String

    private var convertedAmount: String? {
        guard let source = Decimal(string: amount), let multiplier = Decimal(string: rate), multiplier > 0 else { return nil }
        let value = NSDecimalNumber(decimal: source * multiplier)
        return "\(PaktlyCurrencyCatalog.symbol(for: planCurrency))\(value.stringValue)"
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Convert to the plan currency")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Text("This receipt is in \(sourceCurrency), while the plan uses \(planCurrency). Enter the rate shown by your card or trusted currency source.")
                        .font(.subheadline)
                        .foregroundStyle(PaktlyColor.secondaryInk)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("EXCHANGE RATE").font(.caption2.weight(.bold)).tracking(0.9).foregroundStyle(PaktlyColor.secondaryInk)
                    HStack {
                        Text("1 \(sourceCurrency) =")
                        TextField("0.00", text: $rate).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        Text(planCurrency)
                    }
                    .padding(15)
                    .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 16))
                }
                if let convertedAmount {
                    Label("Receipt total will be recorded as approximately \(convertedAmount) in this plan.", systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(PaktlyColor.forest)
                }
                Text("The rate is locked to this expense and will not change when market rates move later.")
                    .font(.caption)
                    .foregroundStyle(PaktlyColor.secondaryInk)
                Spacer()
                Button("Use this rate") { dismiss() }
                    .buttonStyle(PaktlyPrimaryButtonStyle())
                    .disabled((Decimal(string: rate) ?? 0) <= 0)
            }
            .padding(20)
            .background(PaktlyColor.background.ignoresSafeArea())
            .navigationTitle("Currency conversion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Not now") { dismiss() } } }
        }
    }
}
