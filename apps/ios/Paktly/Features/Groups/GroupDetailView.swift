import SwiftUI
import UIKit

struct GroupDetailView: View {
    enum PlanTab: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case expenses = "Expenses"
        case balances = "Balances"
        case members = "Members"
        case activity = "Activity"

        var id: String { rawValue }
    }

    @EnvironmentObject private var model: AppModel
    let groupID: String
    @State private var group: APIGroup?
    @State private var members: [APIGroupMember] = []
    @State private var expenses: [APIExpense] = []
    @State private var balances: [APIBalance] = []
    @State private var suggestions: [APISuggestedSettlement] = []
    @State private var events: [APIActivity] = []
    @State private var showingExpense = false
    @State private var editing: APIExpense?
    @State private var inviting = false
    @State private var selectedTab: PlanTab = .overview
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            if let error {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            }

            Picker("Plan view", selection: $selectedTab) {
                ForEach(PlanTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.top, 8)

            ScrollView {
                LazyVStack(spacing: 16, pinnedViews: []) {
                    planHeader

                    switch selectedTab {
                    case .overview:
                        overviewContent
                    case .expenses:
                        expensesContent
                    case .balances:
                        balancesContent
                    case .members:
                        membersContent
                    case .activity:
                        activityContent
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .scrollIndicators(.hidden)
        }
        .background(PaktlyColor.background.ignoresSafeArea())
        .navigationTitle(group?.name ?? "Plan")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    inviting = true
                } label: {
                    Label("Invite", systemImage: "person.badge.plus")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editing = nil
                    showingExpense = true
                } label: {
                    Label("Add expense", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingExpense) {
            ExpenseEditorView(
                groupID: groupID,
                currency: group?.defaultCurrency ?? "USD",
                members: members,
                existing: editing,
                completed: {
                    await load()
                }
            )
        }
        .sheet(isPresented: $inviting, onDismiss: {
            Task { await load() }
        }) {
            InviteView(groupID: groupID, canManageJoinLink: ["OWNER", "ADMIN"].contains(group?.role ?? ""))
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private var planHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let group {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.name)
                            .font(.title2.bold())
                            .foregroundStyle(PaktlyColor.ink)

                        if let description = group.description, !description.isEmpty {
                            Text(description)
                                .font(.subheadline)
                                .foregroundStyle(PaktlyColor.secondaryInk)
                                .lineLimit(2)
                        }

                        Text("\(members.count) members · \(group.defaultCurrency)")
                            .font(.caption)
                            .foregroundStyle(PaktlyColor.secondaryInk)
                    }

                    Spacer()

                    if let role = group.role, !role.isEmpty {
                        Text(role)
                            .font(.caption.weight(.semibold))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(PaktlyColor.mint.opacity(0.24))
                            .clipShape(Capsule())
                    }
                }
            }

            if let ownBalance = ownNetMinor {
                HStack(spacing: 14) {
                    metric("You owe", value: ownBalance < 0 ? currencyFormatter(-ownBalance, currency: group?.defaultCurrency ?? "USD") : nil, tone: .negative)
                    metric("You're owed", value: ownBalance > 0 ? currencyFormatter(ownBalance, currency: group?.defaultCurrency ?? "USD") : nil, tone: .positive)
                }
            }

            if !suggestions.isEmpty {
                suggestedSettlePanel
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PaktlyColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(PaktlyColor.secondaryInk.opacity(0.16), lineWidth: 1)
        )
    }

    private var overviewContent: some View {
        VStack(spacing: 14) {
            sectionTitle("Latest expenses")
            if expenses.isEmpty {
                contentUnavailable("No expenses yet", "Your first split will appear here.")
            } else {
                ForEach(expenses.prefix(3)) { expense in
                    expenseRow(expense)
                }

                if expenses.count > 3 {
                    Button("View all expenses") {
                        selectedTab = .expenses
                    }
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            sectionTitle("Recent activity")
            if events.isEmpty {
                contentUnavailable("No activity yet", "Invites, expenses, and settlements will appear here.")
            } else {
                ForEach(events.prefix(4)) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.summary)
                            .font(.subheadline)
                            .foregroundStyle(PaktlyColor.ink)
                        Text(event.createdAt, style: .relative)
                            .font(.caption)
                            .foregroundStyle(PaktlyColor.secondaryInk)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(PaktlyColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private var expensesContent: some View {
        VStack(spacing: 14) {
            sectionTitle("Expenses")
            if expenses.isEmpty {
                contentUnavailable("No expenses yet", "Add your first expense to start splitting automatically.")
            } else {
                ForEach(expenses) { expense in
                    expenseCard(expense)
                }
            }
        }
    }

    private var balancesContent: some View {
        VStack(spacing: 14) {
            sectionTitle("Balances")
            ForEach(balances) { row in
                HStack {
                    Text(row.displayName)
                        .foregroundStyle(PaktlyColor.ink)
                    Spacer()
                    Text(currencyFormatter(row.netMinor, currency: group?.defaultCurrency ?? "USD"))
                        .font(.headline)
                        .foregroundStyle(row.netMinor >= 0 ? PaktlyColor.forest : PaktlyColor.coral)
                }
                .padding(12)
                .background(PaktlyColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            if balances.isEmpty {
                contentUnavailable("All settled", "No one owes anything right now.")
            }
        }
    }

    private var membersContent: some View {
        VStack(spacing: 14) {
            HStack {
                sectionTitle("Members")
                Spacer()
                Button("Invite") { inviting = true }
                    .font(.subheadline.weight(.medium))
            }

            ForEach(members) { member in
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(member.displayName)
                            .font(.subheadline.weight(.semibold))
                        Text(member.email)
                            .font(.caption)
                            .foregroundStyle(PaktlyColor.secondaryInk)
                    }
                    Spacer()
                    Text(member.role.capitalized)
                        .font(.caption)
                        .foregroundStyle(PaktlyColor.secondaryInk)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background(PaktlyColor.surface)
                        .clipShape(Capsule())
                }
                .padding(12)
                .background(PaktlyColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if members.isEmpty {
                contentUnavailable("No members yet", "Invite others to split your plan together.")
            }
        }
    }

    private var activityContent: some View {
        VStack(spacing: 14) {
            sectionTitle("Activity")
            if events.isEmpty {
                contentUnavailable("No activity yet", "Edits, invites and settlements will show here.")
            } else {
                ForEach(events) { event in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(PaktlyColor.lavender.opacity(0.45))
                            .frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.summary)
                                .font(.subheadline)
                                .foregroundStyle(PaktlyColor.ink)
                            Text(event.createdAt, style: .date)
                                .font(.caption)
                                .foregroundStyle(PaktlyColor.secondaryInk)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(PaktlyColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private var suggestedSettlePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Suggested settlements")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PaktlyColor.ink)

            ForEach(suggestions) { suggestion in
                HStack {
                    Text("Auto settle this suggested amount")
                        .font(.caption)
                        .foregroundStyle(PaktlyColor.secondaryInk)
                    Spacer()
                    Text(currencyFormatter(suggestion.amountMinor, currency: group?.defaultCurrency ?? "USD"))
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(PaktlyColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Button("Record settlement") {
                    Task {
                        do {
                            try await model.client.settle(
                                groupID: groupID,
                                from: suggestion.fromUserId,
                                to: suggestion.toUserId,
                                amountMinor: suggestion.amountMinor
                            )
                            await load()
                        } catch {
                            self.error = "Could not record settlement."
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PaktlyColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(PaktlyColor.secondaryInk.opacity(0.16), lineWidth: 1)
        )
    }

    private func expenseRow(_ expense: APIExpense) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(expense.description)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PaktlyColor.ink)
                Text("Paid by \(expense.payerName ?? "member") · \(expense.splitMethod.capitalized)")
                    .font(.caption)
                    .foregroundStyle(PaktlyColor.secondaryInk)
            }

            Spacer()

            Text(currencyFormatter(expense.originalAmountMinor, currency: expense.originalCurrency))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PaktlyColor.ink)
        }
        .padding(12)
        .background(PaktlyColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func expenseCard(_ expense: APIExpense) -> some View {
        HStack {
            Button {
                editing = expense
                showingExpense = true
            } label: {
                expenseRow(expense)
            }
            .buttonStyle(.plain)

            Menu {
                Button("Edit") {
                    editing = expense
                    showingExpense = true
                }

                Button("Delete", role: .destructive) {
                    Task {
                        do {
                            try await model.client.deleteExpense(id: expense.id)
                            await load()
                        } catch {
                            self.error = "Could not delete this expense."
                        }
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(PaktlyColor.secondaryInk)
                    .frame(width: 28)
            }
        }
    }

    private var ownNetMinor: Int? {
        guard let userId = model.currentUser?.id else { return nil }
        return balances.first { $0.userId == userId }?.netMinor
    }

    private func sectionTitle(_ value: String) -> some View {
        Text(value)
            .font(.title3.weight(.bold))
            .foregroundStyle(PaktlyColor.ink)
    }

    private func contentUnavailable(_ title: String, _ message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(PaktlyColor.secondaryInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(PaktlyColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(PaktlyColor.secondaryInk.opacity(0.16), lineWidth: 1)
            )
    }

    private func metric(_ title: String, value: String?, tone: MetricTone) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(PaktlyColor.secondaryInk)
            Spacer()
            Text(value ?? "$0.00")
                .font(.headline.weight(.bold))
                .foregroundStyle(tone.color)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(PaktlyColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(tone.color.opacity(0.35), lineWidth: 1)
        )
    }

    private func currencyFormatter(_ minor: Int, currency: String) -> String {
        (Double(minor) / 100).formatted(.currency(code: currency))
    }

    private func load() async {
        do {
            let d = try await model.client.group(groupID)
            group = d.0
            members = d.1
            self.error = nil
        } catch {
            self.error = "We couldn’t load this plan."
            return
        }

        async let expenseList = model.client.expenses(groupID: groupID)
        async let balanceData = model.client.balances(groupID: groupID)
        async let activityData = model.client.activity(groupID: groupID)

        expenses = (try? await expenseList) ?? []
        if let b = try? await balanceData {
            balances = b.0
            suggestions = b.1
        } else {
            balances = []
            suggestions = []
        }
        events = (try? await activityData) ?? []
    }

    private enum MetricTone {
        case positive
        case negative

        var color: Color {
            switch self {
            case .positive:
                return PaktlyColor.forest
            case .negative:
                return PaktlyColor.coral
            }
        }
    }
}

private struct InviteView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let groupID: String
    let canManageJoinLink: Bool
    @State private var identifier = ""
    @State private var developmentToken: String?
    @State private var sending = false
    @State private var errorMessage: String?
    @State private var sentIdentifier: String?
    @State private var joinLink: APIJoinLink?
    @State private var creatingLink = false

    private var normalizedIdentifier: String {
        identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bring someone in")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(PaktlyColor.ink)
                        Text("Invite an existing Paktly member by username, or use any email address. New members will receive a secure account-creation link.")
                            .font(.subheadline)
                            .foregroundStyle(PaktlyColor.secondaryInk)
                            .lineSpacing(2)
                    }

                    VStack(alignment: .leading, spacing: 9) {
                        Text("USERNAME OR EMAIL")
                            .font(.caption2.weight(.bold))
                            .tracking(0.9)
                            .foregroundStyle(PaktlyColor.secondaryInk)
                        HStack(spacing: 10) {
                            Image(systemName: "person.badge.plus")
                                .foregroundStyle(PaktlyColor.secondaryInk)
                            TextField("@username or friend@example.com", text: $identifier)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .textContentType(.username)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 56)
                        .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .stroke(PaktlyColor.secondaryInk.opacity(0.16), lineWidth: 1)
                        }
                    }

                    if let sentIdentifier {
                        Label("Invitation sent to \(sentIdentifier)", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PaktlyColor.forest)
                            .padding(15)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(PaktlyColor.mint.opacity(0.25), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                    }
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(PaktlyColor.coral)
                    }

                    Button { Task { await sendInvitation() } } label: {
                        HStack(spacing: 8) {
                            if sending { ProgressView().tint(PaktlyColor.background) }
                            Text(sending ? "Sending…" : "Send invitation")
                        }
                    }
                    .buttonStyle(PaktlyPrimaryButtonStyle())
                    .disabled(normalizedIdentifier.count < 3 || sending)

                    if canManageJoinLink {
                        Divider()

                        VStack(alignment: .leading, spacing: 10) {
                            Text("SHAREABLE PLAN LINK")
                                .font(.caption2.weight(.bold))
                                .tracking(0.9)
                                .foregroundStyle(PaktlyColor.secondaryInk)
                            Text("Let people join without entering an email. Links expire after seven days and can be replaced or revoked at any time.")
                                .font(.subheadline)
                                .foregroundStyle(PaktlyColor.secondaryInk)
                                .fixedSize(horizontal: false, vertical: true)

                            if let joinLink {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text("JOIN CODE").font(.caption2.weight(.bold)).foregroundStyle(PaktlyColor.secondaryInk)
                                            Text(joinLink.code).font(.title3.monospaced().weight(.bold)).foregroundStyle(PaktlyColor.ink)
                                        }
                                        Spacer()
                                        ShareLink(item: joinLink.url) {
                                            Label("Share", systemImage: "square.and.arrow.up")
                                                .font(.subheadline.weight(.semibold))
                                        }
                                    }
                                    Text("Expires \(joinLink.expiresAt, style: .relative) · Up to \(joinLink.maxUses) joins")
                                        .font(.caption)
                                        .foregroundStyle(PaktlyColor.secondaryInk)
                                    HStack {
                                        Button("Copy link") { UIPasteboard.general.url = joinLink.url }
                                        Spacer()
                                        Button("Revoke", role: .destructive) { Task { await revokeJoinLink() } }
                                    }
                                    .font(.subheadline.weight(.semibold))
                                }
                                .padding(16)
                                .background(PaktlyColor.mint.opacity(0.2), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                            } else {
                                Button {
                                    Task { await createJoinLink() }
                                } label: {
                                    HStack(spacing: 8) {
                                        if creatingLink { ProgressView() }
                                        Label(creatingLink ? "Creating…" : "Create share link", systemImage: "link")
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.large)
                                .disabled(creatingLink)
                            }
                        }
                    }

                    if let developmentToken {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("LOCAL TESTING TOKEN").font(.caption2.weight(.bold)).tracking(0.8)
                            Text(developmentToken).font(.caption.monospaced()).textSelection(.enabled)
                            ShareLink(item: developmentToken) { Label("Share token", systemImage: "square.and.arrow.up") }
                        }
                        .foregroundStyle(PaktlyColor.secondaryInk)
                        .padding(15)
                        .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                    }
                }
                .padding(20)
            }
            .background(PaktlyColor.background.ignoresSafeArea())
            .navigationTitle("Invite people")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func sendInvitation() async {
        guard normalizedIdentifier.count >= 3, !sending else { return }
        sending = true
        errorMessage = nil
        sentIdentifier = nil
        do {
            developmentToken = try await model.client.invite(groupID: groupID, identifier: normalizedIdentifier)
            sentIdentifier = normalizedIdentifier
            identifier = ""
        } catch {
            developmentToken = nil
            errorMessage = "We couldn’t send this invitation. Check the username or email and try again."
        }
        sending = false
    }

    private func createJoinLink() async {
        guard !creatingLink else { return }
        creatingLink = true
        errorMessage = nil
        do {
            joinLink = try await model.client.createJoinLink(groupID: groupID)
        } catch {
            errorMessage = "We couldn’t create a share link. Please try again."
        }
        creatingLink = false
    }

    private func revokeJoinLink() async {
        do {
            try await model.client.revokeJoinLink(groupID: groupID)
            joinLink = nil
        } catch {
            errorMessage = "We couldn’t revoke this share link. Please try again."
        }
    }
}
