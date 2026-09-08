import AuthenticationServices
import SwiftUI
import UserNotifications

struct AccountDeletionView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var pushNotifications: PushNotificationService
    @Environment(\.dismiss) private var dismiss
    @State private var options: APIAccountDeletionOptions?
    @State private var loading = true
    @State private var deleting = false
    @State private var confirmed = false
    @State private var completed = false
    @State private var nonce: String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Delete your Paktly account?").font(.title2.weight(.semibold))
                    Text("This permanently removes your profile, sign-in connections, saved friends, notifications, and Paktly Smart interest. You’ll be signed out on all devices.")
                }
                Section("Shared plans and balances") {
                    Text("Shared monetary records remain under “Deleted member” so other members’ balances stay correct. Your identifying descriptions are removed. Deletion does not pay or forgive outstanding expenses.")
                    Text("If you own a plan, another active member becomes its owner. Deleting Paktly does not close an independent smart wallet or erase blockchain records. Keep access to your wallet’s passkey.")
                    Text("Pending expenses saved only on this phone will be discarded.")
                }
                Section {
                    Link("Account deletion and privacy details", destination: URL(string: "https://paktly.io/account-deletion")!)
                }
                if loading {
                    Section { ProgressView("Checking your account…") }
                } else if let options, options.available {
                    Section {
                        Toggle("I understand this cannot be undone", isOn: $confirmed)
                            .disabled(deleting)
                        if options.requiresApple {
                            Text("Confirm with the Apple account you use for Paktly to disconnect Sign in with Apple and delete your account.")
                                .font(.footnote)
                            SignInWithAppleButton(.continue) { request in
                                let value = AppleAuthNonce.make()
                                nonce = value
                                request.nonce = AppleAuthNonce.sha256(value)
                                request.requestedScopes = []
                            } onCompletion: { result in
                                handleApple(result)
                            }
                            .signInWithAppleButtonStyle(.black)
                            .frame(height: 50)
                            .disabled(!confirmed || deleting)
                        } else {
                            Button("Permanently delete account", role: .destructive) {
                                Task { await delete() }
                            }
                            .disabled(!confirmed || deleting)
                        }
                        if deleting { ProgressView("Deleting account…") }
                    }
                } else if options != nil {
                    Section { Text("Apple account deletion is temporarily unavailable. Please try again later.") }
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(PaktlyColor.coral) }
                }
                if !loading && options == nil {
                    Button("Try again") { Task { await load() } }
                }
            }
            .navigationTitle("Delete account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(deleting)
                }
            }
            .interactiveDismissDisabled(deleting)
            .task { await load() }
            .alert("Account deleted", isPresented: $completed) {
                Button("Done") { Task { await session.signOut() } }
            } message: {
                Text("Your Paktly account and personal profile have been removed.")
            }
        }
    }

    private func load() async {
        loading = true
        errorMessage = nil
        defer { loading = false }
        do { options = try await model.client.accountDeletionOptions() }
        catch { errorMessage = "We couldn’t check your account. Please try again." }
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let codeData = credential.authorizationCode,
                  let code = String(data: codeData, encoding: .utf8), let nonce else {
                errorMessage = "Apple confirmation was incomplete. Please try again."
                return
            }
            Task { await delete(apple: APIAppleDeletionProof(authorizationCode: code, nonce: nonce)) }
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code != .canceled {
                errorMessage = "Apple confirmation didn’t finish. Please try again."
            }
        }
    }

    private func delete(apple: APIAppleDeletionProof? = nil) async {
        guard confirmed, !deleting else { return }
        deleting = true
        errorMessage = nil
        do {
            guard try await model.client.deleteAccount(apple: apple) else {
                errorMessage = "Deletion was not confirmed. Please try again."
                deleting = false
                return
            }
            await model.clearDeletedAccountData()
            KeychainTokenStore.clear()
            await pushNotifications.clearDeletedAccountRegistration()
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            completed = true
        } catch {
            errorMessage = "We couldn’t complete deletion. Check your connection and try again."
            deleting = false
        }
    }
}
