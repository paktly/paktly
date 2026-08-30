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
                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Profile")
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(PaktlyColor.ink)
                        Text("Manage your account and security")
                            .font(.subheadline)
                            .foregroundStyle(PaktlyColor.secondaryInk)
                    }
                    .padding(.horizontal, 20)

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
                            Text("Smart account")
                                .font(.headline)
                            Text("Network")
                                .font(.caption)
                                .foregroundStyle(PaktlyColor.secondaryInk)
                            Text(smartAccount.network.capitalized)
                            Divider()

                            Text("Address")
                                .font(.caption)
                                .foregroundStyle(PaktlyColor.secondaryInk)
                            Text(smartAccount.address)
                                .font(.system(.footnote, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    }

                    PaktlyPanel {
                        Text("Security")
                            .font(.headline)
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Passkey active", systemImage: "faceid")
                            Label("Devices & sessions", systemImage: "laptopcomputer.and.iphone")
                        }
                        .foregroundStyle(PaktlyColor.secondaryInk)
                    }

                    PaktlyPanel {
                        Button("Sign out", role: .destructive) {
                            Task { await session.signOut() }
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                }
                .padding(.horizontal, 16)
            }
            .background(PaktlyColor.background.ignoresSafeArea())
            .navigationTitle("Profile")
            .task(id: model.currentUser?.id) { loadProfile() }
        }
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
