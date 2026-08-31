import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var session: AppSession
    @State private var pendingMode: SmartAccountAuthenticationMode?
    @State private var showingCreateAccount = false
    @State private var signupUsername = PaktlyUsernameSuggestion.make()

    var body: some View {
        ZStack {
            PaktlyColor.background.ignoresSafeArea()
            Circle()
                .fill(PaktlyColor.mint)
                .frame(width: 420, height: 420)
                .blur(radius: 2)
                .offset(x: 150, y: -300)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                Image(systemName: "person.3.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(PaktlyColor.forest)
                    .padding(18)
                    .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 20))
                    .accessibilityHidden(true)

                Text("Plan together.\nPay together.\nStay square.")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .tracking(-1.7)
                    .minimumScaleFactor(0.72)
                    .padding(.top, 28)

                Text("One place for shared plans, shared spending, and everyone involved.")
                    .font(.title3)
                    .foregroundStyle(PaktlyColor.secondaryInk)
                    .lineSpacing(5)
                    .padding(.top, 20)

                Spacer()

                Button {
                    authenticate(.signIn)
                } label: {
                    HStack {
                        if pendingMode == .signIn {
                            ProgressView().tint(PaktlyColor.background)
                        } else {
                            Image(systemName: "faceid")
                        }
                        Text(pendingMode == .signIn ? "Signing in…" : "Continue with passkey")
                    }
                }
                .buttonStyle(PaktlyPrimaryButtonStyle())
                .disabled(pendingMode != nil)

                Button {
                    signupUsername = PaktlyUsernameSuggestion.make()
                    showingCreateAccount = true
                } label: {
                    HStack {
                        if pendingMode == .signUp {
                            ProgressView()
                        }
                        Text(pendingMode == .signUp ? "Creating account…" : "Create an account")
                    }
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 16))
                .controlSize(.large)
                .padding(.top, 18)
                .disabled(pendingMode != nil)

                if session.state == .failed {
                    Text(session.errorMessage ?? "We couldn’t sign you in. Please try again.")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                }

                Text("No password or seed phrase required.")
                    .font(.footnote)
                    .foregroundStyle(PaktlyColor.secondaryInk)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 14)
            }
            .padding(24)
        }
        .foregroundStyle(PaktlyColor.ink)
        .sheet(isPresented: $showingCreateAccount) {
            SignupUsernameView(username: $signupUsername, isWorking: pendingMode != nil) {
                authenticate(.signUp, username: signupUsername)
            }
            .environmentObject(session)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled(pendingMode != nil)
        }
    }

    private func authenticate(_ mode: SmartAccountAuthenticationMode, username: String? = nil) {
        guard pendingMode == nil else { return }
        pendingMode = mode
        Task { @MainActor in
            await session.authenticate(mode: mode, username: username)
            pendingMode = nil
        }
    }
}

private struct SignupUsernameView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @Binding var username: String
    let isWorking: Bool
    let continueAction: () -> Void

    private var normalized: String {
        username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var isValid: Bool {
        normalized.range(of: #"^[a-z0-9](?:[a-z0-9_\-]{1,28}[a-z0-9])$"#, options: .regularExpression) != nil
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Choose your Paktly ID")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Text("This will label your passkey and identify you inside Paktly. You can change your Paktly profile name later.")
                        .font(.subheadline)
                        .foregroundStyle(PaktlyColor.secondaryInk)
                }

                VStack(alignment: .leading, spacing: 8) {
                    TextField("paktly_sunny_otter_4821", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.body.monospaced())
                        .padding(15)
                        .background(PaktlyColor.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    Text(isValid ? "3–30 letters, numbers, hyphens, or underscores." : "Enter 3–30 valid characters.")
                        .font(.caption)
                        .foregroundStyle(isValid ? PaktlyColor.secondaryInk : PaktlyColor.coral)
                }

                if session.state == .failed, let message = session.errorMessage {
                    Text(message).font(.footnote).foregroundStyle(PaktlyColor.coral)
                }

                Button {
                    username = normalized
                    continueAction()
                } label: {
                    HStack {
                        if isWorking { ProgressView().tint(PaktlyColor.background) }
                        Text(isWorking ? "Creating account…" : "Continue with passkey")
                    }
                }
                .buttonStyle(PaktlyPrimaryButtonStyle())
                .disabled(!isValid || isWorking)
                Spacer(minLength: 0)
            }
            .padding(24)
            .background(PaktlyColor.surface.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }.disabled(isWorking)
                }
            }
        }
    }
}

private enum PaktlyUsernameSuggestion {
    private static let adjectives = ["bright", "calm", "happy", "kind", "lucky", "sunny", "swift"]
    private static let nouns = ["bear", "bird", "fox", "koala", "otter", "panda", "tiger"]

    static func make() -> String {
        "paktly_\(adjectives.randomElement() ?? "happy")_\(nouns.randomElement() ?? "otter")_\(Int.random(in: 1000...9999))"
    }
}
