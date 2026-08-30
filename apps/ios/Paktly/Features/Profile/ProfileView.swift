import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var model: AppModel
    @State private var displayName = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Profile") {
                    TextField("Display name", text: $displayName)
                    if let email = model.currentUser?.email { Text(email).foregroundStyle(.secondary) }
                    Button("Save profile") { Task { try? await model.updateProfile(displayName: displayName) } }.disabled(displayName.isEmpty || displayName == model.currentUser?.displayName)
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
            .onAppear { displayName = model.currentUser?.displayName ?? "" }
        }
    }
}
