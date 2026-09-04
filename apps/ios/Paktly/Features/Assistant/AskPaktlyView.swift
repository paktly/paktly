import SwiftUI
import UIKit

struct AskPaktlyView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var recorder = PaktlyVoiceRecorder()
    @StateObject private var realtime = PaktlyRealtimeTranscriber()
    let contextPlanID: String?
    var completed: (() -> Void)? = nil
    @State private var transcript: String?
    @State private var draft: APIAssistantDraft?
    @State private var confirmationToken: String?
    @State private var confirmationIdempotencyKey = UUID().uuidString
    @State private var isProcessing = false
    @State private var isStarting = false
    @State private var isConfirming = false
    @State private var attemptedAutomaticStart = false
    @State private var errorMessage: String?
    @State private var isRealtimeAvailable = false
    @State private var editedName = ""
    @State private var editedDescription = ""
    @State private var editedAmount = ""
    @State private var editedInvitees = ""
    @State private var isEditingDraft = false
    @State private var microphoneNeedsSettings = false
    @State private var isReturningFromSettings = false
    @State private var realtimeStartTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 26) {
                    voiceStage
                    if let transcript { heardCard(transcript) }
                    if let draft { review(draft) }
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .font(.footnote).foregroundStyle(PaktlyColor.coral)
                            .multilineTextAlignment(.center)
                    }
                    Label(
                        "Your voice is transcribed securely as you speak. Paktly removes the temporary recording after processing.",
                        systemImage: "lock.shield"
                    )
                    .font(.caption)
                    .foregroundStyle(PaktlyColor.secondaryInk)
                    .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20).padding(.vertical, 24)
            }
            .background(PaktlyColor.background.ignoresSafeArea())
            .navigationTitle("Speak to Paktly")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { recorder.cancel(); dismiss() }
                }
            }
            .onChange(of: recorder.automaticallyCompletedURL) { _, url in
                if let url { process(url) }
            }
            .task {
                guard !attemptedAutomaticStart else { return }
                attemptedAutomaticStart = true
                await startRecording()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active, isReturningFromSettings else { return }
                isReturningFromSettings = false
                microphoneNeedsSettings = false
                errorMessage = nil
            }
        }
    }

    private var voiceStage: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(recorder.isRecording ? PaktlyColor.coral.opacity(0.16) : PaktlyColor.mint.opacity(0.42))
                    .frame(width: 150, height: 150)
                    .scaleEffect(recorder.isRecording ? 1.06 : 1)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: recorder.isRecording)
                Button { toggleRecording() } label: {
                    Group {
                        if isStarting { ProgressView().tint(.white) }
                        else { Image(systemName: recorder.isRecording ? "stop.fill" : microphoneNeedsSettings ? "gearshape.fill" : "mic.fill") }
                    }
                        .font(.system(size: 38, weight: .semibold)).foregroundStyle(.white)
                        .frame(width: 92, height: 92)
                        .background(recorder.isRecording ? PaktlyColor.coral : PaktlyColor.forest, in: Circle())
                        .shadow(color: PaktlyColor.forest.opacity(0.18), radius: 18, y: 9)
                }
                .buttonStyle(.plain).disabled(isStarting || isProcessing || isConfirming)
                .accessibilityLabel(recorder.isRecording ? "Stop recording" : microphoneNeedsSettings ? "Open microphone settings" : "Start recording")
            }
            VStack(spacing: 7) {
                Text(stageTitle)
                    .font(.system(.title2, design: .rounded, weight: .bold)).foregroundStyle(PaktlyColor.ink)
                Text(stageSubtitle)
                    .font(.subheadline).foregroundStyle(PaktlyColor.secondaryInk)
                    .multilineTextAlignment(.center).frame(maxWidth: 320)
            }
            if recorder.isRecording {
                Text(recorder.formattedDuration)
                    .font(.system(.body, design: .monospaced, weight: .semibold))
                    .foregroundStyle(PaktlyColor.coral)
            }
            if recorder.isRecording, !isRealtimeAvailable {
                Label("Live words are unavailable. Your command will be transcribed when you stop.", systemImage: "waveform.badge.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(PaktlyColor.secondaryInk)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 330)
            }
            if recorder.isRecording, !livePreview.isEmpty {
                Text(livePreview)
                    .font(.body)
                    .foregroundStyle(PaktlyColor.ink)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 330)
                    .padding(15)
                    .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                    .accessibilityLabel("Live transcript: \(livePreview)")
            }
        }
        .padding(.top, 8)
    }

    private var stageTitle: String {
        if isStarting { return "Getting ready…" }
        if isProcessing { return "Understanding…" }
        if recorder.isRecording { return "Listening…" }
        if let draft { return draft.needsClarification ? "One more detail" : "Ready for your review" }
        return "Say it. Paktly sets it up."
    }

    private var stageSubtitle: String {
        if isStarting { return "Paktly will begin listening automatically." }
        if isProcessing { return "Turning your recording into a clear action." }
        if recorder.isRecording { return "Tap stop when you’re finished. Recordings end automatically after one minute." }
        if draft != nil { return "Nothing changes until you confirm below." }
        return "Try “Add the $48 dinner I paid for everyone in Lisbon.”"
    }

    private func heardCard(_ value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("I HEARD").font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(PaktlyColor.secondaryInk)
            Text("“\(value)”").font(.body).foregroundStyle(PaktlyColor.ink)
            Button("Record again") { Task { await startRecording() } }
                .font(.subheadline.weight(.semibold)).foregroundStyle(PaktlyColor.forest)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(17)
        .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func review(_ value: APIAssistantDraft) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(value.needsClarification ? "NEEDS MORE DETAIL" : "REVIEW BEFORE SAVING")
                .font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(PaktlyColor.secondaryInk)
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Label(value.summary, systemImage: icon(for: value.intent)).font(.headline).foregroundStyle(PaktlyColor.ink)
                    Spacer()
                    if value.intent != "UNSUPPORTED" && !value.needsClarification {
                        Button(isEditingDraft ? "Done" : "Edit") { withAnimation(.easeInOut(duration: 0.2)) { isEditingDraft.toggle() } }
                            .font(.subheadline.weight(.semibold)).foregroundStyle(PaktlyColor.forest)
                    }
                }
                if value.intent == "UNSUPPORTED" {
                    Text("Speak to Paktly currently helps with expenses, plans, and invitations.")
                        .font(.subheadline).foregroundStyle(PaktlyColor.secondaryInk)
                } else if value.needsClarification {
                    Text(value.clarification ?? "Please record again with a little more detail.")
                        .font(.subheadline).foregroundStyle(PaktlyColor.secondaryInk)
                    Button("Record with more detail") { Task { await startRecording() } }
                        .buttonStyle(PaktlySecondaryButtonStyle())
                } else {
                    reviewDetails(value)
                    Button { confirm(value) } label: {
                        HStack {
                            if isConfirming { ProgressView().tint(.white) }
                            Text(isConfirming ? "Saving…" : confirmTitle(for: value.intent))
                        }.frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PaktlyPrimaryButtonStyle()).disabled(isConfirming)
                }
            }
            .padding(17).background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private func reviewDetails(_ value: APIAssistantDraft) -> some View {
        if let plan = plan(for: value.planId) { detailRow("Plan", plan.name) }
        if value.description != nil {
            if isEditingDraft { editableRow("What was it for?", text: $editedDescription) }
            else { detailRow("For", editedDescription) }
        }
        if let currency = value.currency, value.amountMinor != nil {
            if isEditingDraft { editableRow("Amount (\(currency))", text: $editedAmount, keyboard: .decimalPad) }
            else { detailRow("Amount", "\(currency) \(editedAmount)") }
        }
        if value.intent == "CREATE_EXPENSE" { detailRow("Split", splitSummary(value)) }
        if value.planName != nil {
            if isEditingDraft { editableRow("Plan name", text: $editedName) }
            else { detailRow("Name", editedName) }
        }
        if value.intent == "CREATE_PLAN", !editedDescription.isEmpty {
            if isEditingDraft { editableRow("Description", text: $editedDescription) }
            else { detailRow("About", editedDescription) }
        }
        if value.intent == "INVITE_PERSON" {
            if isEditingDraft { editableRow("People", text: $editedInvitees) }
            else { detailRow("Invite", editedInvitees) }
        }
        if let start = value.planStartDate { detailRow("Starts", start) }
        if let end = value.planEndDate { detailRow("Ends", end) }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(.subheadline).foregroundStyle(PaktlyColor.secondaryInk)
            Spacer(minLength: 20)
            Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(PaktlyColor.ink).multilineTextAlignment(.trailing)
        }
    }

    private func editableRow(_ label: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).font(.caption2.weight(.bold)).tracking(0.8).foregroundStyle(PaktlyColor.secondaryInk)
            TextField(label, text: text, axis: .vertical)
                .keyboardType(keyboard)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PaktlyColor.ink)
                .padding(.vertical, 10).padding(.horizontal, 12)
                .background(PaktlyColor.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func toggleRecording() {
        if recorder.isRecording {
            guard let url = recorder.stop() else { return }
            process(url)
        } else {
            if microphoneNeedsSettings {
                if let settings = URL(string: UIApplication.openSettingsURLString) {
                    isReturningFromSettings = true
                    openURL(settings)
                }
                return
            }
            Task { await startRecording() }
        }
    }

    private func startRecording() async {
        reset()
        isStarting = true
        defer { isStarting = false }
        do {
            let liveTranscriber = realtime
            try await recorder.start { data in liveTranscriber.append(data) }
            realtimeStartTask?.cancel()
            realtimeStartTask = Task { @MainActor in
                do {
                    try await liveTranscriber.start(client: model.client)
                    guard !Task.isCancelled, recorder.isRecording else {
                        liveTranscriber.stop()
                        return
                    }
                    isRealtimeAvailable = true
                } catch {
                    liveTranscriber.stop()
                    isRealtimeAvailable = false
                }
            }
            microphoneNeedsSettings = false
        }
        catch PaktlyVoiceRecorder.RecorderError.microphonePermissionDenied {
            microphoneNeedsSettings = true
            errorMessage = "Microphone access is off. Tap the settings button to allow access for Paktly."
        } catch { errorMessage = "We couldn’t start recording. Please try again." }
    }

    private func process(_ url: URL) {
        isProcessing = true
        errorMessage = nil
        Task {
            defer { try? FileManager.default.removeItem(at: url); isProcessing = false }
            do {
                // Realtime text is intentionally preview-only. A completed-file
                // transcription is more accurate for names, amounts, and goals,
                // and is always the source passed to action interpretation.
                _ = try? await realtime.finish()
                let text = try await model.client.transcribeAssistant(audioURL: url)
                transcript = text
                let interpretation = try await model.client.interpretAssistant(prompt: text, contextPlanId: contextPlanID)
                draft = interpretation.draft
                confirmationToken = interpretation.confirmationToken
                populateEditableFields(interpretation.draft)
                isEditingDraft = false
            } catch {
                errorMessage = "Paktly couldn’t hear that clearly or turn it into an action. Please record again."
            }
        }
    }

    private func reset() {
        realtimeStartTask?.cancel(); realtimeStartTask = nil
        recorder.cancel(); realtime.stop(); isRealtimeAvailable = false
        transcript = nil; draft = nil; confirmationToken = nil
        confirmationIdempotencyKey = UUID().uuidString; errorMessage = nil
    }

    private func confirm(_ value: APIAssistantDraft) {
        errorMessage = nil; isConfirming = true
        Task {
            do {
                guard let confirmationToken else { throw AssistantActionError.invalidDraft }
                let verified = try await model.client.confirmAssistant(
                    token: confirmationToken,
                    idempotencyKey: confirmationIdempotencyKey,
                    overrides: confirmationOverrides(for: value)
                )
                switch verified.intent {
                case "CREATE_PLAN":
                    guard let name = verified.planName else { throw AssistantActionError.invalidDraft }
                    _ = try await model.client.createGroup(name: name, description: verified.planDescription, currency: verified.currency ?? "USD", clientOperationId: confirmationIdempotencyKey)
                    await model.refresh()
                case "INVITE_PERSON":
                    guard let planID = verified.planId else { throw AssistantActionError.invalidDraft }
                    let identifiers = verified.inviteIdentifiers?.isEmpty == false ? verified.inviteIdentifiers! : [verified.inviteIdentifier].compactMap { $0 }
                    guard !identifiers.isEmpty else { throw AssistantActionError.invalidDraft }
                    for identifier in identifiers { _ = try await model.client.invite(groupID: planID, identifier: identifier) }
                    await model.refresh()
                case "CREATE_EXPENSE":
                    guard let planID = verified.planId, let description = verified.description,
                          let amount = verified.amountMinor, let payer = verified.payerId,
                          !verified.participantIds.isEmpty else { throw AssistantActionError.invalidDraft }
                    let expense = ExpenseDraft(
                        clientOperationId: confirmationIdempotencyKey, description: description, category: verified.category ?? "Other",
                        amountMinor: amount, currency: verified.currency ?? "USD", paidBy: payer,
                        expenseDate: parsedDate(verified.expenseDate) ?? Date(), notes: "Added with Speak to Paktly",
                        split: expenseSplit(verified)
                    )
                    guard await model.submitExpense(groupID: planID, draft: expense) else { throw AssistantActionError.saveFailed }
                    await model.refresh()
                default: throw AssistantActionError.invalidDraft
                }
                completed?()
                dismiss()
            } catch { errorMessage = "We couldn’t save this yet. Please record it again or use the standard form." }
            isConfirming = false
        }
    }

    private func plan(for id: String?) -> APIGroup? {
        guard let id else { return nil }; return model.groups.first { $0.id == id }
    }
    private func money(_ amount: Int, currency: String) -> String {
        let formatter = NumberFormatter(); formatter.numberStyle = .currency; formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: Double(amount) / 100)) ?? "\(currency) \(Double(amount) / 100)"
    }
    private func icon(for intent: String) -> String {
        switch intent { case "CREATE_EXPENSE": "banknote"; case "CREATE_PLAN": "square.stack.3d.up.fill"; case "INVITE_PERSON": "person.badge.plus"; default: "questionmark.bubble" }
    }
    private func confirmTitle(for intent: String) -> String {
        switch intent { case "CREATE_EXPENSE": "Add expense"; case "CREATE_PLAN": "Create plan"; case "INVITE_PERSON": "Send invitation"; default: "Confirm" }
    }

    private func splitSummary(_ draft: APIAssistantDraft) -> String {
        switch draft.splitMethod ?? "EQUAL" {
        case "EXACT": return "Exact amounts"
        case "PERCENTAGE": return "By percentage"
        case "SHARES": return "By shares"
        case "ITEMIZED": return "Itemized"
        default: return "Equally between \(draft.participantIds.count) people"
        }
    }

    private func expenseSplit(_ draft: APIAssistantDraft) -> ExpenseDraft.Split {
        let method = draft.splitMethod ?? "EQUAL"
        let values = (draft.splitValues ?? []).compactMap { value -> ExpenseDraft.Weighted? in
            guard let id = value.participantId else { return nil }
            return .init(userId: id, value: value.value)
        }
        if method == "ITEMIZED" {
            let items = (draft.splitValues ?? []).compactMap { value -> ExpenseDraft.Item? in
                guard let id = value.participantId else { return nil }
                return .init(amountMinor: value.value, participantIds: [id])
            }
            return .init(method: method, participantIds: nil, shares: nil, items: items)
        }
        if method == "EQUAL" { return .init(method: method, participantIds: draft.participantIds, shares: nil, items: nil) }
        return .init(method: method, participantIds: nil, shares: values, items: nil)
    }

    private func parsedDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = DateFormatter(); formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private func populateEditableFields(_ value: APIAssistantDraft) {
        editedName = value.planName ?? ""
        editedDescription = value.intent == "CREATE_PLAN" ? (value.planDescription ?? "") : (value.description ?? "")
        editedAmount = value.amountMinor.map { String(format: "%.2f", Double($0) / 100) } ?? ""
        editedInvitees = (value.inviteIdentifiers?.isEmpty == false ? value.inviteIdentifiers! : [value.inviteIdentifier].compactMap { $0 }).joined(separator: ", ")
    }

    private var livePreview: String {
        let openAI = realtime.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        return openAI.isEmpty ? recorder.liveTranscript : openAI
    }

    private func confirmationOverrides(for value: APIAssistantDraft) -> APIAssistantOverrides {
        let amount = Decimal(string: editedAmount.replacingOccurrences(of: ",", with: "."))
            .map { NSDecimalNumber(decimal: $0 * 100).intValue }
        let invitees = editedInvitees.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return APIAssistantOverrides(
            planName: value.intent == "CREATE_PLAN" ? editedName : nil,
            planDescription: value.intent == "CREATE_PLAN" ? editedDescription : nil,
            description: value.intent == "CREATE_EXPENSE" ? editedDescription : nil,
            amountMinor: value.intent == "CREATE_EXPENSE" ? amount : nil,
            category: value.category,
            expenseDate: value.expenseDate,
            inviteIdentifiers: value.intent == "INVITE_PERSON" ? invitees : nil
        )
    }
}

private enum AssistantActionError: Error { case invalidDraft, saveFailed }
