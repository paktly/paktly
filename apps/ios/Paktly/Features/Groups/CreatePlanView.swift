import SwiftUI

enum PlanType: String, CaseIterable, Identifiable {
    case trip = "Trip"
    case home = "Household"
    case celebration = "Celebration"
    case event = "Event"
    case project = "Project"
    case other = "Other"

    var id: String { rawValue }
    var subtitle: String {
        switch self {
        case .trip:
            return "Weekend escapes, vacations, and city trips."
        case .home:
            return "House shares, joint expenses, and recurring planning."
        case .celebration:
            return "Weddings, birthdays, and holidays."
        case .event:
            return "Conferences, meetings, and socials."
        case .project:
            return "Any collaborative purchase or initiative."
        case .other:
            return "Custom shared plan outside these categories."
        }
    }
}

struct CreatePlanView: View {
    enum Step: Int, CaseIterable {
        case details = 0
        case money
        case members
        case review

        var title: String {
            switch self {
            case .details: return "Plan details"
            case .money: return "Money setup"
            case .members: return "Members"
            case .review: return "Review"
            }
        }
    }

    struct PlanDraft {
        var name = ""
        var type: PlanType = .trip
        var details = ""
        var currency = "USD"
        var memberEmails: [String] = []
    }

    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft = PlanDraft()
    @State private var currentStep: Step = .details
    @State private var memberEmailInput = ""
    @State private var creating = false
    @State private var createError: String?
    @State private var stepError: String?
    @State private var currencyText = "USD"
    @FocusState private var isEmailFocused: Bool

    private let supportedCurrencies = ["USD", "EUR", "GBP", "CAD", "AUD", "JPY", "SGD", "CHF", "NOK"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressHeader

                ScrollView {
                    VStack(spacing: 22) {
                        section
                    }
                    .padding(20)
                }

                HStack(spacing: 14) {
                    if currentStep != .details {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                stepBack()
                            }
                        } label: {
                            Text("Back")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle(radius: 14))
                    }

                    Button {
                        Task {
                            await nextOrCreate()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if creating {
                                ProgressView().tint(PaktlyColor.background)
                            }
                            Text(primaryButtonTitle)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(PaktlyPrimaryButtonStyle())
                    .disabled(!canContinue || creating)
                }
                .padding(16)
                .background(PaktlyColor.surface)
            }
            .background(PaktlyColor.background.ignoresSafeArea())
            .navigationTitle("Create plan")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Set it up in a few steps")
                    .font(.headline)
                    .foregroundStyle(PaktlyColor.ink)
                Spacer()
                Text("Step \(currentStep.rawValue + 1) of \(Step.allCases.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PaktlyColor.secondaryInk)
            }
            progressIndicator
        }
        .padding(20)
        .background(PaktlyColor.surface)
    }

    private var progressIndicator: some View {
        HStack(spacing: 10) {
            ForEach(Step.allCases, id: \.self) { step in
                HStack(spacing: 8) {
                    Capsule()
                        .fill(step.rawValue <= currentStep.rawValue ? PaktlyColor.forest : PaktlyColor.surface)
                        .frame(height: 6)
                        .frame(maxWidth: .infinity)
                    Text(step.rawValue == currentStep.rawValue ? "●" : "○")
                        .font(.caption2)
                        .foregroundStyle(step.rawValue <= currentStep.rawValue ? PaktlyColor.forest : PaktlyColor.secondaryInk)
                }
            }
        }
        .foregroundStyle(PaktlyColor.secondaryInk)
    }

    @ViewBuilder
    private var section: some View {
        switch currentStep {
        case .details:
            detailsSection
        case .money:
            moneySection
        case .members:
            membersSection
        case .review:
            reviewSection
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("What are you planning together?")

            card {
                VStack(spacing: 14) {
                    LabeledContent("Plan name") {
                        TextField("Weekend in Lisbon", text: $draft.name)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.next)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Plan type")
                            .font(.subheadline)
                            .foregroundStyle(PaktlyColor.secondaryInk)
                        Picker("Plan type", selection: $draft.type) {
                            ForEach(PlanType.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text(draft.type.subtitle)
                            .font(.footnote)
                            .foregroundStyle(PaktlyColor.secondaryInk)
                    }

                    Divider()

                    LabeledContent("Description") {
                        TextField("Optional notes for your plan", text: $draft.details, axis: .vertical)
                            .lineLimit(3...4)
                    }
                }
            }

            if let stepError {
                formError
            }
        }
    }

    private var moneySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("How will money move?")

            card {
                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Default currency")
                            .font(.subheadline)
                            .foregroundStyle(PaktlyColor.secondaryInk)
                        TextField("USD", text: $currencyText)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .onChange(of: currencyText) { newValue in
                                let normalized = newValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                                currencyText = normalized
                                draft.currency = normalized
                            }
                        Text("Currency can be changed later in plan preferences.")
                            .font(.footnote)
                            .foregroundStyle(PaktlyColor.secondaryInk)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Popular currencies")
                            .font(.subheadline)
                            .foregroundStyle(PaktlyColor.secondaryInk)

                    FlowLayout(spacing: 8) {
                            ForEach(supportedCurrencies, id: \.self) { currency in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.12)) {
                                        draft.currency = currency
                                        currencyText = currency
                                    }
                                } label: {
                                    Text(currency)
                                        .font(.subheadline.weight(.semibold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(draft.currency == currency ? PaktlyColor.forest.opacity(0.16) : PaktlyColor.surface)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(draft.currency == currency ? PaktlyColor.forest : PaktlyColor.secondaryInk.opacity(0.3), lineWidth: 1)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            if let stepError {
                formError
            }
        }
    }

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Invite the people who join")

            card {
                VStack(spacing: 12) {
                    HStack(alignment: .top, spacing: 8) {
                        TextField("friend@example.com", text: $memberEmailInput)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .focused($isEmailFocused)
                            .onSubmit { addMemberEmail() }

                        Button {
                            addMemberEmail()
                        } label: {
                            Image(systemName: "plus")
                                .frame(width: 40, height: 40)
                                .background(PaktlyColor.mint)
                                .clipShape(Circle())
                                .foregroundStyle(PaktlyColor.ink)
                        }
                        .disabled(!isValidEmail(memberEmailInput))
                    }

                    if draft.memberEmails.isEmpty {
                        Text("You can add members later from the plan detail screen.")
                            .font(.footnote)
                            .foregroundStyle(PaktlyColor.secondaryInk)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], alignment: .leading, spacing: 8) {
                            ForEach(draft.memberEmails, id: \.self) { email in
                                HStack(spacing: 8) {
                                    Text(email)
                                        .lineLimit(1)
                                        .font(.footnote)
                                    Button {
                                        draft.memberEmails.removeAll { $0 == email }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(PaktlyColor.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(PaktlyColor.secondaryInk.opacity(0.18), lineWidth: 1)
                                )
                            }
                        }
                    }

                    Text("Invites are sent after the plan is created.")
                        .font(.footnote)
                        .foregroundStyle(PaktlyColor.secondaryInk)
                }
            }

            if let stepError {
                formError
            }
        }
    }

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Review before create")

            card {
                VStack(alignment: .leading, spacing: 10) {
                    Label {
                        Text("Plan name")
                    } icon: {
                        Image(systemName: "text.badge.star")
                    }

                    Text(draft.name.isEmpty ? "Unnamed plan" : draft.name)
                        .font(.title3.bold())

                    LabeledContent("Type") {
                        Text(draft.type.rawValue)
                    }
                    Divider()
                    LabeledContent("Currency") { Text(draft.currency.isEmpty ? "USD" : draft.currency) }
                    Divider()
                    LabeledContent("Members to invite") {
                        Text(draft.memberEmails.isEmpty ? "None now" : "\(draft.memberEmails.count) email(s)")
                    }

                    if !draft.details.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notes")
                                .font(.caption)
                                .foregroundStyle(PaktlyColor.secondaryInk)
                            Text(draft.details)
                                .font(.subheadline)
                                .foregroundStyle(PaktlyColor.ink)
                        }
                    }
                }
            }

            if let createError {
                Text(createError)
                    .font(.footnote)
                    .foregroundStyle(PaktlyColor.coral)
                    .padding(.horizontal, 2)
            }
        }
    }

    private var formError: some View {
        Text(stepError ?? "")
            .font(.footnote)
            .foregroundStyle(PaktlyColor.coral)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var primaryButtonTitle: String {
        switch currentStep {
        case .review:
            return creating ? "Creating…" : "Create plan"
        default:
            return "Continue"
        }
    }

    private var canContinue: Bool {
        guard stepError == nil else { return false }
        switch currentStep {
        case .details:
            return !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .money:
            return isValidCurrency(draft.currency)
        case .members:
            return true
        case .review:
            return !creating
        }
    }

    private func nextOrCreate() async {
        guard stepError == nil else { return }

        guard validateCurrentStep() else { return }

        if currentStep == .review {
            creating = true
            createError = nil
            let normalizedCurrency = draft.currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let normalizedDescription = [draft.type.rawValue, draft.details].
                filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: " · ")

            do {
                _ = try await model.createPlan(
                    name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: normalizedDescription.isEmpty ? nil : normalizedDescription,
                    currency: normalizedCurrency,
                    memberEmails: draft.memberEmails
                )
                dismiss()
            } catch {
                createError = "Could not create the plan. Please try again."
                creating = false
                isEmailFocused = false
            }
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            guard let next = Step(rawValue: currentStep.rawValue + 1) else { return }
            currentStep = next
        }
    }

    private func stepBack() {
        guard let previous = Step(rawValue: currentStep.rawValue - 1) else { return }
        stepError = nil
        currentStep = previous
    }

    private func validateCurrentStep() -> Bool {
        switch currentStep {
        case .details:
            if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                stepError = "Enter a plan name to continue."
                return false
            } else {
                stepError = nil
                return true
            }
        case .money:
            if !isValidCurrency(draft.currency) {
                stepError = "Use a valid 3-letter currency code."
                return false
            } else {
                stepError = nil
                return true
            }
        case .members, .review:
            stepError = nil
            return true
        }
    }

    private func isValidCurrency(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard trimmed.count == 3 else { return false }
        return trimmed.allSatisfy { $0.isLetter }
    }

    private func isValidEmail(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.contains("@") && trimmed.contains(".") && trimmed.count > 4
    }

    private func addMemberEmail() {
        let normalized = memberEmailInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard isValidEmail(normalized), !draft.memberEmails.contains(normalized) else { return }
        draft.memberEmails.append(normalized)
        memberEmailInput = ""
        isEmailFocused = false
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.semibold))
            .foregroundStyle(PaktlyColor.ink)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(PaktlyColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(PaktlyColor.secondaryInk.opacity(0.16), lineWidth: 1)
            )
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat

    init(spacing: CGFloat) { self.spacing = spacing }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        var rows = [[CGRect]]()
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var currentRow = [CGRect]()

        for index in 0..<subviews.count {
            let size = subviews[index].sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, !currentRow.isEmpty {
                rows.append(currentRow)
                currentY += currentRowHeight + spacing
                currentX = 0
                currentRowHeight = 0
                currentRow = []
            }

            currentRow.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
            currentX += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
        }

        if !currentRow.isEmpty {
            rows.append(currentRow)
        }

        let maxRowHeight = rows.map { row in row.map { $0.height }.max() ?? 0 }.max() ?? 0
        return CGSize(width: maxWidth, height: currentY + maxRowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var currentRowHeight: CGFloat = 0

        for index in 0..<subviews.count {
            let size = subviews[index].sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentY += currentRowHeight + spacing
                currentX = 0
                currentRowHeight = 0
            }

            let origin = CGPoint(x: bounds.minX + currentX, y: bounds.minY + currentY)
            subviews[index].place(at: origin, anchor: .topLeading, proposal: ProposedViewSize(width: size.width, height: size.height))
            currentX += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
        }
    }
}
