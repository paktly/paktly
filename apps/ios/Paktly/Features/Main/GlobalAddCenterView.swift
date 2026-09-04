import SwiftUI

private enum GlobalAddAction: String, Hashable {
    case expense
    case receipt
    case invite

    var title: String {
        switch self {
        case .expense: "Add expense"
        case .receipt: "Scan receipt"
        case .invite: "Invite people"
        }
    }

    var guidance: String {
        switch self {
        case .expense: "Choose where this expense belongs."
        case .receipt: "Choose the plan for this receipt."
        case .invite: "Choose the plan you want to grow."
        }
    }
}

struct GlobalAddCenterView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let contextPlanID: String?
    @State private var showingCreatePlan = false
    @State private var showingAskPaktly = false
    @State private var expenseContext: ExpensePlanContext?
    @State private var receiptContext: ExpensePlanContext?
    @State private var invitePlan: APIGroup?
    @State private var loadingAction: GlobalAddAction?
    @State private var errorMessage: String?

    private var activePlan: APIGroup? {
        guard let contextPlanID else { return nil }
        return model.groups.first { $0.id == contextPlanID }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("What would you like to add?")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(PaktlyColor.ink)
                        Text("Start anywhere. Paktly will carry the right plan context with you.")
                            .font(.subheadline)
                            .foregroundStyle(PaktlyColor.secondaryInk)
                    }

                    VStack(spacing: 10) {
                        Button { showingAskPaktly = true } label: {
                            actionRow(
                                title: "Speak to Paktly",
                                subtitle: "Say what happened. Review it, then save.",
                                icon: "waveform",
                                tint: PaktlyColor.mint
                            )
                        }
                        .buttonStyle(.plain)

                        contextualActionButton(
                            title: "Scan receipt",
                            subtitle: "Capture the total, then review the payer and split.",
                            icon: "doc.viewfinder",
                            tint: PaktlyColor.lavender,
                            action: .receipt
                        )

                        contextualActionButton(
                            title: "Add expense",
                            subtitle: "Record a cost and split it with your people.",
                            icon: "banknote",
                            tint: PaktlyColor.mint,
                            action: .expense
                        )

                        Button { showingCreatePlan = true } label: {
                            actionRow(
                                title: "Create plan",
                                subtitle: "Bring a trip, home, event, or shared goal together.",
                                icon: "square.stack.3d.up.fill",
                                tint: PaktlyColor.lavender
                            )
                        }
                        .buttonStyle(.plain)

                        contextualActionButton(
                            title: "Invite people",
                            subtitle: "Invite by username, email, link, or join code.",
                            icon: "person.badge.plus",
                            tint: PaktlyColor.coral.opacity(0.5),
                            action: .invite
                        )
                    }

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(PaktlyColor.coral)
                    }

                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(PaktlyColor.background.ignoresSafeArea())
            .navigationTitle("Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationDestination(for: GlobalAddAction.self) { action in
                GlobalPlanPickerView(action: action, completed: { dismiss() })
            }
            .sheet(isPresented: $showingCreatePlan) {
                CreatePlanView(completed: { dismiss() }).environmentObject(model)
            }
            .sheet(isPresented: $showingAskPaktly) {
                AskPaktlyView(contextPlanID: contextPlanID, completed: { dismiss() })
                    .environmentObject(model)
            }
            .sheet(item: $expenseContext) { context in
                ExpenseEditorView(
                    groupID: context.group.id,
                    currency: context.group.defaultCurrency,
                    members: context.members,
                    existing: nil,
                    completed: {
                        await model.refresh()
                        dismiss()
                    }
                )
                .environmentObject(model)
            }
            .sheet(item: $receiptContext) { context in
                ReceiptScannerView(
                    group: context.group,
                    members: context.members,
                    completed: {
                        await model.refresh()
                        dismiss()
                    }
                )
                .environmentObject(model)
            }
            .sheet(item: $invitePlan) { group in
                InviteView(
                    groupID: group.id,
                    canManageJoinLink: ["OWNER", "ADMIN"].contains(group.role ?? ""),
                    completed: { dismiss() }
                )
                .environmentObject(model)
            }
        }
    }

    @ViewBuilder
    private func contextualActionButton(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        action: GlobalAddAction
    ) -> some View {
        if let activePlan {
            Button { open(action, in: activePlan) } label: {
                actionRow(
                    title: title,
                    subtitle: loadingAction == action ? "Opening \(activePlan.name)…" : "\(subtitle) · \(activePlan.name)",
                    icon: icon,
                    tint: tint
                )
            }
            .buttonStyle(.plain)
            .disabled(loadingAction != nil)
        } else {
            NavigationLink(value: action) {
                actionRow(title: title, subtitle: subtitle, icon: icon, tint: tint)
            }
            .buttonStyle(.plain)
        }
    }

    private func open(_ action: GlobalAddAction, in group: APIGroup) {
        errorMessage = nil
        if action == .invite {
            invitePlan = group
            return
        }
        loadingAction = action
        Task {
            do {
                let detail = try await model.client.group(group.id)
                let context = ExpensePlanContext(group: detail.0, members: detail.1)
                if action == .receipt { receiptContext = context } else { expenseContext = context }
            } catch {
                errorMessage = "We couldn’t open this plan. Please try again."
            }
            loadingAction = nil
        }
    }

    private func actionRow(title: String, subtitle: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(PaktlyColor.forest)
                .frame(width: 46, height: 46)
                .background(tint.opacity(0.55), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(PaktlyColor.ink)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(PaktlyColor.secondaryInk)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(PaktlyColor.secondaryInk.opacity(0.65))
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(PaktlyColor.secondaryInk.opacity(0.1), lineWidth: 1)
        }
    }
}

private struct ExpensePlanContext: Identifiable {
    let group: APIGroup
    let members: [APIGroupMember]
    var id: String { group.id }
}

private struct GlobalPlanPickerView: View {
    @EnvironmentObject private var model: AppModel
    let action: GlobalAddAction
    let completed: () -> Void
    @State private var expenseContext: ExpensePlanContext?
    @State private var receiptContext: ExpensePlanContext?
    @State private var invitePlan: APIGroup?
    @State private var loadingPlanID: String?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(action.guidance)
                    .font(.subheadline)
                    .foregroundStyle(PaktlyColor.secondaryInk)

                if model.groups.isEmpty {
                    PaktlyEmptyState(
                        title: "Create a plan first",
                        message: "Expenses and invitations need a shared plan.",
                        icon: "square.stack.3d.up"
                    )
                } else {
                    ForEach(model.groups) { group in
                        Button { select(group) } label: {
                            HStack(spacing: 14) {
                                Image(systemName: action == .invite ? "person.2" : action == .receipt ? "doc.viewfinder" : "receipt")
                                    .font(.headline)
                                    .foregroundStyle(PaktlyColor.forest)
                                    .frame(width: 44, height: 44)
                                    .background(PaktlyColor.mint.opacity(0.35), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(group.name)
                                        .font(.headline)
                                        .foregroundStyle(PaktlyColor.ink)
                                    Text("\(group.memberCount ?? 1) people · \(group.defaultCurrency)")
                                        .font(.caption)
                                        .foregroundStyle(PaktlyColor.secondaryInk)
                                }
                                Spacer()
                                if loadingPlanID == group.id {
                                    ProgressView().tint(PaktlyColor.forest)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(PaktlyColor.secondaryInk)
                                }
                            }
                            .padding(15)
                            .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(loadingPlanID != nil)
                    }
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(PaktlyColor.coral)
                }
            }
            .padding(20)
        }
        .background(PaktlyColor.background.ignoresSafeArea())
        .navigationTitle(action.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $expenseContext) { context in
            ExpenseEditorView(
                groupID: context.group.id,
                currency: context.group.defaultCurrency,
                members: context.members,
                existing: nil,
                completed: {
                    await model.refresh()
                    completed()
                }
            )
            .environmentObject(model)
        }
        .sheet(item: $receiptContext) { context in
            ReceiptScannerView(
                group: context.group,
                members: context.members,
                completed: {
                    await model.refresh()
                    completed()
                }
            )
            .environmentObject(model)
        }
        .sheet(item: $invitePlan) { group in
            InviteView(
                groupID: group.id,
                canManageJoinLink: ["OWNER", "ADMIN"].contains(group.role ?? ""),
                completed: completed
            )
            .environmentObject(model)
        }
    }

    private func select(_ group: APIGroup) {
        errorMessage = nil
        if action == .invite {
            invitePlan = group
            return
        }

        loadingPlanID = group.id
        Task {
            do {
                let detail = try await model.client.group(group.id)
                let context = ExpensePlanContext(group: detail.0, members: detail.1)
                if action == .receipt { receiptContext = context } else { expenseContext = context }
            } catch {
                errorMessage = "We couldn’t open this plan. Please try again."
            }
            loadingPlanID = nil
        }
    }
}
