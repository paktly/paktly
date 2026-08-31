import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var model: AppModel
    @State private var displayName = ""
    @State private var username = ""
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showingWalletActivation = false
    @State private var usernameStatus: UsernameAvailabilityField.Status = .optional

    private var normalizedUsername: String? {
        let value = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return value.isEmpty ? nil : value
    }

    private var hasProfileChanges: Bool {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines) != model.currentUser?.displayName ||
            normalizedUsername != model.currentUser?.username
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    profileHeader

                    PaktlyPanel {
                        VStack(spacing: 12) {
                            LabeledContent("Display name") {
                                TextField("Display name", text: $displayName)
                                    .textInputAutocapitalization(.words)
                            }

                            Divider()

                            VStack(alignment: .leading, spacing: 7) {
                                Text("Username")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(PaktlyColor.secondaryInk)
                                UsernameAvailabilityField(
                                    username: $username,
                                    currentUsername: model.currentUser?.username,
                                    status: $usernameStatus
                                )
                            }

                            if
                                let email = model.currentUser?.email,
                                !email.hasSuffix("@users.paktly.invalid")
                            {
                                Divider()
                                HStack {
                                    Text("Email")
                                    Spacer()
                                    Text(email)
                                        .foregroundStyle(PaktlyColor.secondaryInk)
                                }
                                .font(.subheadline)
                            }

                            Button {
                                Task { await saveProfile() }
                            } label: {
                                if isSaving {
                                    ProgressView().frame(maxWidth: .infinity)
                                } else {
                                    Text("Save profile").frame(maxWidth: .infinity)
                                }
                            }
                            .buttonStyle(PaktlyPrimaryButtonStyle())
                            .disabled(
                                isSaving ||
                                    displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                    !hasProfileChanges ||
                                    !usernameStatus.permitsSaving
                            )

                            if let saveError {
                                Text(saveError)
                                    .font(.footnote)
                                    .foregroundStyle(PaktlyColor.coral)
                            }
                        }
                    }

                    PaktlyPanel {
                        if let smartAccount = model.currentUser?.smartAccount {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Label("Smart account", systemImage: "checkmark.shield.fill")
                                        .font(.headline).foregroundStyle(PaktlyColor.ink)
                                    Spacer()
                                    PaktlyRowPill(text: smartAccount.network.capitalized)
                                }
                                Text(smartAccount.address)
                                    .font(.system(.footnote, design: .monospaced))
                                    .foregroundStyle(PaktlyColor.secondaryInk)
                                    .lineLimit(1).truncationMode(.middle)
                                    .textSelection(.enabled)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 14) {
                                Label("Unlock Paktly Smart", systemImage: "sparkles")
                                    .font(.headline).foregroundStyle(PaktlyColor.ink)
                                Text("Activate a passkey-protected smart wallet when you’re ready to save, contribute, and access eligible payment features.")
                                    .font(.subheadline).foregroundStyle(PaktlyColor.secondaryInk)
                                Button("Activate Smart Wallet") { showingWalletActivation = true }
                                    .buttonStyle(PaktlyPrimaryButtonStyle())
                            }
                        }
                    }

                    PaktlyPanel {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Security").font(.headline).foregroundStyle(PaktlyColor.ink)
                            HStack(spacing: 12) {
                                Image(systemName: model.currentUser?.smartAccount == nil ? "envelope.badge.shield.half.filled" : "person.badge.key.fill")
                                    .foregroundStyle(PaktlyColor.forest)
                                    .frame(width: 38, height: 38)
                                    .background(PaktlyColor.mint.opacity(0.35), in: Circle())
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(model.currentUser?.smartAccount == nil ? "Email verified" : "Wallet passkey active")
                                        .font(.subheadline.weight(.semibold))
                                    Text(model.currentUser?.smartAccount == nil
                                         ? "Your Paktly account uses secure email codes."
                                         : "Your device securely authorizes wallet actions.")
                                        .font(.caption).foregroundStyle(PaktlyColor.secondaryInk)
                                }
                            }
                        }
                    }

                    PaktlyPanel {
                        Button("Sign out", role: .destructive) {
                            Task { await session.signOut() }
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
            .background(PaktlyColor.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .task(id: model.currentUser?.id) { loadProfile() }
            .sheet(isPresented: $showingWalletActivation) {
                SmartWalletActivationView(
                    suggestedUsername: model.currentUser?.username ?? PaktlySmartUsername.make()
                ) {
                    await model.refresh()
                    showingWalletActivation = false
                }
                .environmentObject(session)
                .presentationDetents([.large])
            }
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 12) {
            PaktlyAvatar(name: model.currentUser?.displayName ?? "Paktly user", size: 72)
            VStack(spacing: 4) {
                Text(model.currentUser?.displayName ?? "Your profile")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(PaktlyColor.ink)
                if let username = model.currentUser?.username {
                    Text("@\(username)").font(.subheadline).foregroundStyle(PaktlyColor.secondaryInk)
                } else {
                    Text("Your identity and security").font(.subheadline).foregroundStyle(PaktlyColor.secondaryInk)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func loadProfile() {
        displayName = model.currentUser?.displayName ?? ""
        username = model.currentUser?.username ?? ""
        usernameStatus = model.currentUser?.username == nil ? .optional : .current
    }

    private func saveProfile() async {
        guard !isSaving else { return }
        isSaving = true
        saveError = nil
        defer { isSaving = false }
        do {
            try await model.updateProfile(
                displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                username: normalizedUsername
            )
            loadProfile()
        } catch {
            saveError = "We couldn’t save your Paktly profile. Check that the username is available."
        }
    }
}

private struct SmartWalletActivationView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @State var suggestedUsername: String
    let completed: () async -> Void

    private var normalized: String {
        suggestedUsername.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var valid: Bool {
        normalized.range(of: #"^[a-z0-9](?:[a-z0-9_\-]{1,28}[a-z0-9])$"#, options: .regularExpression) != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Activate Paktly Smart")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        Text("Your everyday Paktly account stays the same. This adds a separate smart wallet protected by a passkey.")
                            .foregroundStyle(PaktlyColor.secondaryInk)
                    }
                    PaktlyPanel {
                        VStack(alignment: .leading, spacing: 15) {
                            capability("Smart Wallet", "Hold supported digital-dollar balances.", "wallet.bifold")
                            capability("Smart Savings", "Put real funds toward shared goals.", "chart.line.uptrend.xyaxis")
                            capability("Eligible payments", "Access supported cards and payments when available in your region.", "creditcard")
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Passkey label").font(.caption.weight(.semibold)).foregroundStyle(PaktlyColor.secondaryInk)
                        TextField("paktly_sunny_otter_4821", text: $suggestedUsername)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .font(.body.monospaced()).padding(15)
                            .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        Text("This labels the passkey on your device. Your Paktly profile can still be edited separately.")
                            .font(.caption).foregroundStyle(PaktlyColor.secondaryInk)
                    }
                    if let message = session.walletActivationError {
                        Text(message).font(.footnote).foregroundStyle(PaktlyColor.coral)
                    }
                    Button {
                        Task {
                            if await session.activateSmartWallet(username: normalized) { await completed() }
                        }
                    } label: {
                        HStack {
                            if session.isActivatingWallet { ProgressView().tint(PaktlyColor.background) }
                            Text(session.isActivatingWallet ? "Activating…" : "Create passkey and activate")
                        }
                    }
                    .buttonStyle(PaktlyPrimaryButtonStyle())
                    .disabled(!valid || session.isActivatingWallet)
                    Text("Wallet availability, funding, and card access may require identity verification and regional eligibility.")
                        .font(.caption).foregroundStyle(PaktlyColor.secondaryInk)
                }
                .padding(24)
            }
            .background(PaktlyColor.background.ignoresSafeArea())
            .toolbar { Button("Close") { dismiss() }.disabled(session.isActivatingWallet) }
            .interactiveDismissDisabled(session.isActivatingWallet)
        }
    }

    private func capability(_ title: String, _ message: String, _ icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundStyle(PaktlyColor.forest).frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(message).font(.caption).foregroundStyle(PaktlyColor.secondaryInk)
            }
        }
    }
}

private enum PaktlySmartUsername {
    static func make() -> String {
        let words = ["bright", "calm", "kind", "lucky", "sunny", "swift"]
        return "paktly_\(words.randomElement() ?? "smart")_\(Int.random(in: 1000...9999))"
    }
}
