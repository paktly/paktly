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
            List {
                Section("Paktly profile") {
                    TextField("Display name", text: $displayName)
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    if
                        let email = model.currentUser?.email,
                        !email.hasSuffix("@users.paktly.invalid")
                    {
                        Text(email).foregroundStyle(.secondary)
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
                    .disabled(
                        isSaving ||
                            displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                            !hasProfileChanges
                    )

                    if let saveError {
                        Text(saveError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                if let smartAccount = model.currentUser?.smartAccount {
                    Section("Smart account") {
                        LabeledContent("Network", value: smartAccount.network.capitalized)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Address")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(smartAccount.address)
                                .font(.system(.footnote, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    }
                }

                Section {
                    Label("Passkey active", systemImage: "faceid")
                    Label("Devices & sessions", systemImage: "laptopcomputer.and.iphone")
                } header: {
                    Text("Security")
                }

                Section {
                    Button("Sign out", role: .destructive) {
                        Task { await session.signOut() }
                    }
                }
            }
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
