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
        case .trip: "Travel, weekends away, and group holidays"
        case .home: "Household costs and recurring shared expenses"
        case .celebration: "Weddings, birthdays, and special occasions"
        case .event: "Conferences, meetups, and social events"
        case .project: "Group purchases and collaborative projects"
        case .other: "Anything else you are organizing together"
        }
    }

    var icon: String {
        switch self {
        case .trip: "airplane"
        case .home: "house.fill"
        case .celebration: "sparkles"
        case .event: "calendar"
        case .project: "hammer.fill"
        case .other: "circle.grid.2x2.fill"
        }
    }
}

struct CreatePlanView: View {
    enum Step: Int, CaseIterable {
        case details
        case money
        case members
        case review

        var title: String {
            switch self {
            case .details: "Details"
            case .money: "Money"
            case .members: "People"
            case .review: "Review"
            }
        }
    }

    private enum FocusField: Hashable {
        case name
        case notes
        case email
    }

    struct PlanDraft {
        var name = ""
        var type: PlanType = .trip
        var details = ""
        var currency = "USD"
        var memberIdentifiers: [String] = []
    }

    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft = PlanDraft()
    @State private var currentStep: Step = .details
    @State private var memberEmailInput = ""
    @State private var creating = false
    @State private var planCreated = false
    @State private var createError: String?
    @State private var stepError: String?
    @State private var showingPlanTypes = false
    @State private var showingCurrencies = false
    @FocusState private var focusedField: FocusField?

    private let supportedCurrencies = ["USD", "EUR", "GBP", "CAD", "AUD", "JPY", "SGD", "CHF", "NOK"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    progressHeader
                    currentSection
                }
                .frame(maxWidth: 560, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 30)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(PaktlyColor.background.ignoresSafeArea())
            .navigationTitle("New plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PaktlyColor.forest)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .safeAreaInset(edge: .bottom) { bottomBar }
            .sheet(isPresented: $showingPlanTypes) {
                PlanTypePicker(selection: $draft.type)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingCurrencies) {
                CurrencyPicker(currencies: supportedCurrencies, selection: $draft.currency)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
        .interactiveDismissDisabled(creating)
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(currentStep.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PaktlyColor.ink)
                Spacer()
                Text("\(currentStep.rawValue + 1) of \(Step.allCases.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PaktlyColor.secondaryInk)
                    .monospacedDigit()
            }
            HStack(spacing: 7) {
                ForEach(Step.allCases, id: \.self) { step in
                    Capsule()
                        .fill(step.rawValue <= currentStep.rawValue
                            ? PaktlyColor.forest
                            : PaktlyColor.secondaryInk.opacity(0.16))
                        .frame(height: 4)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(currentStep.rawValue + 1) of \(Step.allCases.count), \(currentStep.title)")
    }

    @ViewBuilder
    private var currentSection: some View {
        switch currentStep {
        case .details: detailsSection
        case .money: moneySection
        case .members: membersSection
        case .review: reviewSection
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            pageHeading(
                "What are you planning?",
                subtitle: "Give everyone a clear place to coordinate, track costs, and settle up."
            )
            VStack(alignment: .leading, spacing: 20) {
                formField("Plan name", hint: "Choose a name everyone will recognize") {
                    TextField("e.g. Summer in Lisbon", text: $draft.name)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .name)
                        .onSubmit { focusedField = .notes }
                        .onChange(of: draft.name) { _, _ in stepError = nil }
                }
                formField("Plan type", hint: "This helps Paktly tailor the plan") {
                    Button {
                        focusedField = nil
                        showingPlanTypes = true
                    } label: {
                        selectorRow(icon: draft.type.icon, title: draft.type.rawValue, subtitle: draft.type.subtitle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Plan type, \(draft.type.rawValue)")
                    .accessibilityHint("Opens the plan type selector")
                }
                formField("Notes", hint: "Optional") {
                    TextField("Add a short description or shared goal", text: $draft.details, axis: .vertical)
                        .lineLimit(3...5)
                        .focused($focusedField, equals: .notes)
                }
            }
            validationMessage
        }
    }

    private var moneySection: some View {
        VStack(alignment: .leading, spacing: 24) {
            pageHeading(
                "Choose the plan currency",
                subtitle: "Balances and summaries will use this currency. Individual expenses can still be recorded in others."
            )
            formField("Default currency", hint: "Change this before expenses are added") {
                Button {
                    focusedField = nil
                    showingCurrencies = true
                } label: {
                    selectorRow(
                        icon: "banknote.fill",
                        title: currencyDisplayName(draft.currency),
                        subtitle: draft.currency
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Default currency, \(draft.currency)")
                .accessibilityHint("Opens the currency selector")
            }
            infoPanel(
                icon: "globe.americas.fill",
                title: "Built for more than one currency",
                message: "Paktly preserves an expense’s original currency and its recorded conversion rate."
            )
            validationMessage
        }
    }

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            pageHeading(
                "Who’s part of the plan?",
                subtitle: "Invite people now, or keep going and add them from the plan later."
            )
            formField("Username or email", hint: "Sent after the plan is created") {
                HStack(spacing: 10) {
                    TextField("@username or friend@example.com", text: $memberEmailInput)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textContentType(.emailAddress)
                        .submitLabel(.done)
                        .focused($focusedField, equals: .email)
                        .onSubmit { addMemberEmail() }
                    Button { addMemberEmail() } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(PaktlyColor.background)
                            .frame(width: 44, height: 44)
                            .background(PaktlyColor.forest, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!isValidInviteIdentifier(memberEmailInput))
                    .accessibilityLabel("Add invitation")
                }
            }
            if draft.memberIdentifiers.isEmpty {
                infoPanel(
                    icon: "person.2.fill",
                    title: "Start solo if you want",
                    message: "A plan does not need invitations yet. You will be its first admin."
                )
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("PEOPLE TO INVITE")
                        .font(.caption2.weight(.bold))
                        .tracking(0.9)
                        .foregroundStyle(PaktlyColor.secondaryInk)
                    VStack(spacing: 0) {
                        ForEach(Array(draft.memberIdentifiers.enumerated()), id: \.element) { index, email in
                            inviteRow(email)
                            if index < draft.memberIdentifiers.count - 1 {
                                Divider().padding(.leading, 52)
                            }
                        }
                    }
                    .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(PaktlyColor.secondaryInk.opacity(0.13), lineWidth: 1)
                    }
                }
            }
            validationMessage
        }
    }

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            pageHeading(
                "Everything look right?",
                subtitle: "You can edit these details later from plan settings."
            )
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 14) {
                    Image(systemName: draft.type.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(PaktlyColor.forest)
                        .frame(width: 48, height: 48)
                        .background(PaktlyColor.mint.opacity(0.55), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(draft.name.trimmingCharacters(in: .whitespacesAndNewlines))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(PaktlyColor.ink)
                        Text(draft.type.rawValue)
                            .font(.subheadline)
                            .foregroundStyle(PaktlyColor.secondaryInk)
                    }
                    Spacer()
                }
                .padding(18)
                Divider()
                reviewRow("Currency", value: draft.currency)
                Divider().padding(.leading, 18)
                reviewRow("Invitations", value: draft.memberIdentifiers.isEmpty ? "None yet" : "\(draft.memberIdentifiers.count)")
                if !draft.details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Divider().padding(.leading, 18)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("NOTES")
                            .font(.caption2.weight(.bold))
                            .tracking(0.8)
                            .foregroundStyle(PaktlyColor.secondaryInk)
                        Text(draft.details)
                            .font(.subheadline)
                            .foregroundStyle(PaktlyColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(18)
                }
            }
            .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(PaktlyColor.secondaryInk.opacity(0.13), lineWidth: 1)
            }
            if let createError {
                Label(createError, systemImage: "exclamationmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(PaktlyColor.coral)
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if currentStep != .details {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { stepBack() }
                } label: {
                    Text("Back")
                        .font(.headline)
                        .foregroundStyle(PaktlyColor.ink)
                        .frame(width: 96, height: 52)
                        .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(PaktlyColor.secondaryInk.opacity(0.18), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .disabled(creating)
            }
            Button { Task { await nextOrCreate() } } label: {
                HStack(spacing: 8) {
                    if creating { ProgressView().tint(PaktlyColor.background) }
                    Text(primaryButtonTitle)
                }
            }
            .buttonStyle(PaktlyPrimaryButtonStyle())
            .disabled(!canContinue || creating)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider().opacity(0.5) }
    }

    private func pageHeading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(PaktlyColor.ink)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(PaktlyColor.secondaryInk)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func formField<Content: View>(
        _ label: String,
        hint: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PaktlyColor.ink)
                if let hint {
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(PaktlyColor.secondaryInk)
                }
            }
            content()
                .padding(.horizontal, 16)
                .frame(minHeight: 56)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(PaktlyColor.secondaryInk.opacity(0.16), lineWidth: 1)
                }
        }
    }

    private func selectorRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(PaktlyColor.forest)
                .frame(width: 36, height: 36)
                .background(PaktlyColor.mint.opacity(0.5), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(PaktlyColor.ink)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(PaktlyColor.secondaryInk)
                    .lineLimit(1)
            }
            Spacer(minLength: 10)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption.weight(.bold))
                .foregroundStyle(PaktlyColor.secondaryInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func infoPanel(icon: String, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(PaktlyColor.forest)
                .frame(width: 36, height: 36)
                .background(PaktlyColor.mint.opacity(0.42), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(PaktlyColor.ink)
                Text(message).font(.caption).foregroundStyle(PaktlyColor.secondaryInk).lineSpacing(2)
            }
            Spacer(minLength: 0)
        }
        .padding(15)
        .background(PaktlyColor.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func inviteRow(_ email: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "envelope.fill")
                .font(.caption)
                .foregroundStyle(PaktlyColor.forest)
                .frame(width: 36, height: 36)
                .background(PaktlyColor.mint.opacity(0.45), in: Circle())
            Text(email)
                .font(.subheadline)
                .foregroundStyle(PaktlyColor.ink)
                .lineLimit(1)
            Spacer()
            Button {
                draft.memberIdentifiers.removeAll { $0 == email }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PaktlyColor.secondaryInk)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(email)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func reviewRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(PaktlyColor.secondaryInk)
            Spacer()
            Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(PaktlyColor.ink)
        }
        .padding(18)
    }

    @ViewBuilder
    private var validationMessage: some View {
        if let stepError {
            Label(stepError, systemImage: "exclamationmark.circle.fill")
                .font(.footnote)
                .foregroundStyle(PaktlyColor.coral)
        }
    }

    private var primaryButtonTitle: String {
        if planCreated { return "Done" }
        return currentStep == .review ? (creating ? "Creating…" : "Create plan") : "Continue"
    }

    private var canContinue: Bool {
        switch currentStep {
        case .details: !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .money: isValidCurrency(draft.currency)
        case .members: true
        case .review: !creating
        }
    }

    private func nextOrCreate() async {
        if planCreated {
            dismiss()
            return
        }
        guard validateCurrentStep() else { return }
        if currentStep == .review {
            creating = true
            focusedField = nil
            createError = nil
            let normalizedDescription = [draft.type.rawValue, draft.details]
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .joined(separator: " · ")
            do {
                _ = try await model.createPlan(
                    name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: normalizedDescription.isEmpty ? nil : normalizedDescription,
                    currency: draft.currency,
                    memberIdentifiers: draft.memberIdentifiers
                )
                dismiss()
            } catch let failure as PlanInvitationFailure {
                let recipients = failure.failedIdentifiers.joined(separator: ", ")
                createError = "Your plan was created, but we couldn’t invite: \(recipients). Open Members to try again."
                planCreated = true
                creating = false
            } catch {
                createError = "We couldn’t create this plan. Your details are still here—please try again."
                creating = false
            }
            return
        }
        focusedField = nil
        stepError = nil
        withAnimation(.easeInOut(duration: 0.2)) {
            guard let next = Step(rawValue: currentStep.rawValue + 1) else { return }
            currentStep = next
        }
    }

    private func stepBack() {
        guard let previous = Step(rawValue: currentStep.rawValue - 1) else { return }
        focusedField = nil
        stepError = nil
        createError = nil
        currentStep = previous
    }

    private func validateCurrentStep() -> Bool {
        switch currentStep {
        case .details where draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty:
            stepError = "Enter a plan name to continue."
            focusedField = .name
            return false
        case .money where !isValidCurrency(draft.currency):
            stepError = "Choose a supported currency to continue."
            return false
        default:
            stepError = nil
            return true
        }
    }

    private func isValidCurrency(_ value: String) -> Bool {
        supportedCurrencies.contains(value)
    }

    private func isValidInviteIdentifier(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("@") && !trimmed.hasPrefix("@") {
            return trimmed.contains(".") && trimmed.count > 4
        }
        let username = trimmed.lowercased().replacingOccurrences(of: " ", with: "_").trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        return username.count >= 3 && username.count <= 30 && username.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }

    private func addMemberEmail() {
        let normalized = memberEmailInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard isValidInviteIdentifier(normalized) else { return }
        let identifier = normalized.hasPrefix("@")
            ? String(normalized.dropFirst()).replacingOccurrences(of: " ", with: "_")
            : normalized
        guard !draft.memberIdentifiers.contains(identifier) else { return }
        draft.memberIdentifiers.append(identifier)
        memberEmailInput = ""
        focusedField = .email
    }

    private func currencyDisplayName(_ code: String) -> String {
        Locale.current.localizedString(forCurrencyCode: code) ?? code
    }
}

private struct PlanTypePicker: View {
    @Binding var selection: PlanType
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(PlanType.allCases) { type in
                        Button {
                            selection = type
                            dismiss()
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: type.icon)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(PaktlyColor.forest)
                                    .frame(width: 42, height: 42)
                                    .background(PaktlyColor.mint.opacity(0.48), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(type.rawValue)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(PaktlyColor.ink)
                                    Text(type.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(PaktlyColor.secondaryInk)
                                        .lineLimit(2)
                                }
                                Spacer(minLength: 8)
                                if selection == type {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(PaktlyColor.forest)
                                }
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(selection == type ? PaktlyColor.forest.opacity(0.55) : PaktlyColor.secondaryInk.opacity(0.12), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .background(PaktlyColor.background.ignoresSafeArea())
            .navigationTitle("Choose a plan type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.foregroundStyle(PaktlyColor.forest)
                }
            }
        }
    }
}

private struct CurrencyPicker: View {
    let currencies: [String]
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(currencies, id: \.self) { code in
                Button {
                    selection = code
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Locale.current.localizedString(forCurrencyCode: code) ?? code)
                                .foregroundStyle(PaktlyColor.ink)
                            Text(code)
                                .font(.caption)
                                .foregroundStyle(PaktlyColor.secondaryInk)
                        }
                        Spacer()
                        if selection == code {
                            Image(systemName: "checkmark")
                                .font(.body.weight(.bold))
                                .foregroundStyle(PaktlyColor.forest)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(PaktlyColor.surface)
            }
            .scrollContentBackground(.hidden)
            .background(PaktlyColor.background)
            .navigationTitle("Default currency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.foregroundStyle(PaktlyColor.forest)
                }
            }
        }
    }
}
