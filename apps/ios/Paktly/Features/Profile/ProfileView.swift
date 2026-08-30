import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var model: AppModel
    @State private var displayName = ""
    @State private var username = ""
    @State private var isSaving = false
    @State private var saveError: String?

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

                            LabeledContent("Username") {
                                TextField("Username", text: $username)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
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
                                    !hasProfileChanges
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
                            Label("Smart account is being prepared", systemImage: "hourglass")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(PaktlyColor.secondaryInk)
                        }
                    }

                    PaktlyPanel {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Security").font(.headline).foregroundStyle(PaktlyColor.ink)
                            HStack(spacing: 12) {
                                Image(systemName: "faceid")
                                    .foregroundStyle(PaktlyColor.forest)
                                    .frame(width: 38, height: 38)
                                    .background(PaktlyColor.mint.opacity(0.35), in: Circle())
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Passkey protected").font(.subheadline.weight(.semibold))
                                    Text("Your device securely authorizes access.").font(.caption).foregroundStyle(PaktlyColor.secondaryInk)
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
