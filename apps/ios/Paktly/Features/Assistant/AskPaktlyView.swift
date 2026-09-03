import SwiftUI

struct AskPaktlyView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let contextPlanID: String?

    @State private var prompt = ""
    @State private var draft: APIAssistantDraft?
    @State private var isThinking = false
    @State private var isConfirming = false
    @State private var errorMessage: String?

    private let examples = [
        "Add the $35 taxi I paid to Lisbon",
        "Invite alex@example.com to Bali",
        "Create a house renovation plan"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    intro
                    composer
                    if let draft { review(draft) } else { suggestions }
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(PaktlyColor.coral)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
            .background(PaktlyColor.background.ignoresSafeArea())
            .navigationTitle("Ask Paktly")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var intro: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(PaktlyColor.forest)
                .frame(width: 48, height: 48)
                .background(PaktlyColor.mint.opacity(0.45), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                Text("Add it naturally")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(PaktlyColor.ink)
                Text("Describe an expense, a new plan, or someone to invite. You’ll review everything before it’s saved.")
                    .font(.subheadline)
                    .foregroundStyle(PaktlyColor.secondaryInk)
            }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextEditor(text: $prompt)
                .font(.body)
                .foregroundStyle(PaktlyColor.ink)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 108)
                .padding(12)
                .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if prompt.isEmpty {
                        Text("e.g. Add the $48 dinner I paid for everyone in Lisbon")
                            .font(.body)
                            .foregroundStyle(PaktlyColor.secondaryInk.opacity(0.65))
                            .padding(.horizontal, 17)
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(PaktlyColor.secondaryInk.opacity(0.13), lineWidth: 1)
                }

            Button { interpret() } label: {
                HStack(spacing: 9) {
                    if isThinking { ProgressView().tint(.white) }
                    else { Image(systemName: "arrow.up") }
                    Text(isThinking ? "Understanding…" : "Continue")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PaktlyPrimaryButtonStyle())
            .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 || isThinking || isConfirming)
        }
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TRY SAYING")
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(PaktlyColor.secondaryInk)
            ForEach(examples, id: \.self) { example in
                Button { prompt = example } label: {
                    HStack {
                        Text(example).font(.subheadline).foregroundStyle(PaktlyColor.ink)
                        Spacer()
                        Image(systemName: "arrow.up.left").font(.caption.weight(.bold))
                            .foregroundStyle(PaktlyColor.forest)
                    }
                    .padding(14)
                    .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func review(_ value: APIAssistantDraft) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(value.needsClarification ? "ONE MORE DETAIL" : "REVIEW BEFORE SAVING")
                .font(.caption.weight(.bold)).tracking(1.2)
                .foregroundStyle(PaktlyColor.secondaryInk)

            VStack(alignment: .leading, spacing: 12) {
                Label(value.summary, systemImage: icon(for: value.intent))
                    .font(.headline)
                    .foregroundStyle(PaktlyColor.ink)

                if value.intent == "UNSUPPORTED" {
                    Text("Ask Paktly currently helps with expenses, plans, and invitations.")
                        .font(.subheadline)
                        .foregroundStyle(PaktlyColor.secondaryInk)
                } else if value.needsClarification {
                    Text(value.clarification ?? "Please add a little more detail above.")
                        .font(.subheadline)
                        .foregroundStyle(PaktlyColor.secondaryInk)
                } else {
                    reviewDetails(value)
                    Button { confirm(value) } label: {
                        HStack {
                            if isConfirming { ProgressView().tint(.white) }
                            Text(isConfirming ? "Saving…" : confirmTitle(for: value.intent))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PaktlyPrimaryButtonStyle())
                    .disabled(isConfirming)
                }
            }
            .padding(17)
            .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    @ViewBuilder
    private func reviewDetails(_ value: APIAssistantDraft) -> some View {
        if let plan = plan(for: value.planId) { detailRow("Plan", plan.name) }
        if let description = value.description { detailRow("Expense", description) }
        if let amount = value.amountMinor, let currency = value.currency {
            detailRow("Amount", money(amount, currency: currency))
        }
        if value.intent == "CREATE_EXPENSE" {
            detailRow("Split", "Equally between \(value.participantIds.count) people")
        }
        if let name = value.planName { detailRow("Name", name) }
        if let invitee = value.inviteIdentifier { detailRow("Invite", invitee) }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(.subheadline).foregroundStyle(PaktlyColor.secondaryInk)
            Spacer(minLength: 20)
            Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(PaktlyColor.ink)
                .multilineTextAlignment(.trailing)
        }
    }

    private func interpret() {
        errorMessage = nil
        draft = nil
        isThinking = true
        Task {
            do {
                draft = try await model.client.interpretAssistant(
                    prompt: prompt.trimmingCharacters(in: .whitespacesAndNewlines),
                    contextPlanId: contextPlanID
                )
            } catch {
                errorMessage = "Paktly couldn’t understand that right now. Please try again."
            }
            isThinking = false
        }
    }

    private func confirm(_ value: APIAssistantDraft) {
        errorMessage = nil
        isConfirming = true
        Task {
            do {
                switch value.intent {
                case "CREATE_PLAN":
                    guard let name = value.planName else { throw AssistantActionError.invalidDraft }
                    try await model.createGroup(name: name, description: value.planDescription, currency: value.currency ?? "USD")
                case "INVITE_PERSON":
                    guard let planID = value.planId, let identifier = value.inviteIdentifier else { throw AssistantActionError.invalidDraft }
                    _ = try await model.client.invite(groupID: planID, identifier: identifier)
                    await model.refresh()
                case "CREATE_EXPENSE":
                    guard let planID = value.planId,
                          let description = value.description,
                          let amount = value.amountMinor,
                          let payer = value.payerId,
                          !value.participantIds.isEmpty else { throw AssistantActionError.invalidDraft }
                    let expense = ExpenseDraft(
                        clientOperationId: UUID().uuidString,
                        description: description,
                        category: "Other",
                        amountMinor: amount,
                        currency: value.currency ?? "USD",
                        paidBy: payer,
                        expenseDate: Date(),
                        notes: "Added with Ask Paktly",
                        split: .init(method: "EQUAL", participantIds: value.participantIds, shares: nil, items: nil)
                    )
                    guard await model.submitExpense(groupID: planID, draft: expense) else { throw AssistantActionError.saveFailed }
                    await model.refresh()
                default:
                    throw AssistantActionError.invalidDraft
                }
                dismiss()
            } catch {
                errorMessage = "We couldn’t save this yet. Review the details and try again."
            }
            isConfirming = false
        }
    }

    private func plan(for id: String?) -> APIGroup? {
        guard let id else { return nil }
        return model.groups.first { $0.id == id }
    }

    private func money(_ amount: Int, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: Double(amount) / 100)) ?? "\(currency) \(Double(amount) / 100)"
    }

    private func icon(for intent: String) -> String {
        switch intent {
        case "CREATE_EXPENSE": "banknote"
        case "CREATE_PLAN": "square.stack.3d.up.fill"
        case "INVITE_PERSON": "person.badge.plus"
        default: "questionmark.bubble"
        }
    }

    private func confirmTitle(for intent: String) -> String {
        switch intent {
        case "CREATE_EXPENSE": "Add expense"
        case "CREATE_PLAN": "Create plan"
        case "INVITE_PERSON": "Send invitation"
        default: "Confirm"
        }
    }
}

private enum AssistantActionError: Error {
    case invalidDraft
    case saveFailed
}
