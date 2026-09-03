import SwiftUI

struct AskPaktlyView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recorder = PaktlyVoiceRecorder()
    let contextPlanID: String?
    @State private var transcript: String?
    @State private var draft: APIAssistantDraft?
    @State private var isProcessing = false
    @State private var isStarting = false
    @State private var isConfirming = false
    @State private var attemptedAutomaticStart = false
    @State private var errorMessage: String?

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
                        "Live words are sent for AI interpretation. If live text is unavailable, Paktly securely transcribes the recording, then removes it from this device.",
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
                        else { Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill") }
                    }
                        .font(.system(size: 38, weight: .semibold)).foregroundStyle(.white)
                        .frame(width: 92, height: 92)
                        .background(recorder.isRecording ? PaktlyColor.coral : PaktlyColor.forest, in: Circle())
                        .shadow(color: PaktlyColor.forest.opacity(0.18), radius: 18, y: 9)
                }
                .buttonStyle(.plain).disabled(isStarting || isProcessing || isConfirming)
                .accessibilityLabel(recorder.isRecording ? "Stop recording" : "Start recording")
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
            if recorder.isRecording, !recorder.liveTranscript.isEmpty {
                Text(recorder.liveTranscript)
                    .font(.body)
                    .foregroundStyle(PaktlyColor.ink)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 330)
                    .padding(15)
                    .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                    .accessibilityLabel("Live transcript: \(recorder.liveTranscript)")
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
                Label(value.summary, systemImage: icon(for: value.intent)).font(.headline).foregroundStyle(PaktlyColor.ink)
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
        if let description = value.description { detailRow("Expense", description) }
        if let amount = value.amountMinor, let currency = value.currency { detailRow("Amount", money(amount, currency: currency)) }
        if value.intent == "CREATE_EXPENSE" { detailRow("Split", "Equally between \(value.participantIds.count) people") }
        if let name = value.planName { detailRow("Name", name) }
        if let invitee = value.inviteIdentifier { detailRow("Invite", invitee) }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(.subheadline).foregroundStyle(PaktlyColor.secondaryInk)
            Spacer(minLength: 20)
            Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(PaktlyColor.ink).multilineTextAlignment(.trailing)
        }
    }

    private func toggleRecording() {
        if recorder.isRecording {
            guard let url = recorder.stop() else { return }
            process(url)
        } else {
            Task { await startRecording() }
        }
    }

    private func startRecording() async {
        reset()
        isStarting = true
        defer { isStarting = false }
        do { try await recorder.start() }
        catch PaktlyVoiceRecorder.RecorderError.microphonePermissionDenied {
            errorMessage = "Microphone access is off. Enable it for Paktly in Settings to use voice actions."
        } catch PaktlyVoiceRecorder.RecorderError.speechPermissionDenied {
            errorMessage = "Speech Recognition access is off. Enable it for Paktly in Settings to see words while you speak."
        } catch { errorMessage = "We couldn’t start recording. Please try again." }
    }

    private func process(_ url: URL) {
        let liveText = recorder.liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        isProcessing = true
        errorMessage = nil
        Task {
            defer { try? FileManager.default.removeItem(at: url); isProcessing = false }
            do {
                let text: String
                if liveText.count >= 2 {
                    text = liveText
                } else {
                    text = try await model.client.transcribeAssistant(audioURL: url)
                }
                transcript = text
                draft = try await model.client.interpretAssistant(prompt: text, contextPlanId: contextPlanID)
            } catch {
                errorMessage = liveText.count >= 2
                    ? "Paktly couldn’t turn that into an action. Please try again or use the standard form."
                    : "Paktly couldn’t hear that clearly. Please record again."
            }
        }
    }

    private func reset() {
        recorder.cancel(); transcript = nil; draft = nil; errorMessage = nil
    }

    private func confirm(_ value: APIAssistantDraft) {
        errorMessage = nil; isConfirming = true
        Task {
            do {
                switch value.intent {
                case "CREATE_PLAN":
                    guard let name = value.planName else { throw AssistantActionError.invalidDraft }
                    try await model.createGroup(name: name, description: value.planDescription, currency: value.currency ?? "USD")
                case "INVITE_PERSON":
                    guard let planID = value.planId, let identifier = value.inviteIdentifier else { throw AssistantActionError.invalidDraft }
                    _ = try await model.client.invite(groupID: planID, identifier: identifier); await model.refresh()
                case "CREATE_EXPENSE":
                    guard let planID = value.planId, let description = value.description,
                          let amount = value.amountMinor, let payer = value.payerId,
                          !value.participantIds.isEmpty else { throw AssistantActionError.invalidDraft }
                    let expense = ExpenseDraft(
                        clientOperationId: UUID().uuidString, description: description, category: "Other",
                        amountMinor: amount, currency: value.currency ?? "USD", paidBy: payer,
                        expenseDate: Date(), notes: "Added with Speak to Paktly",
                        split: .init(method: "EQUAL", participantIds: value.participantIds, shares: nil, items: nil)
                    )
                    guard await model.submitExpense(groupID: planID, draft: expense) else { throw AssistantActionError.saveFailed }
                    await model.refresh()
                default: throw AssistantActionError.invalidDraft
                }
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
}

private enum AssistantActionError: Error { case invalidDraft, saveFailed }
