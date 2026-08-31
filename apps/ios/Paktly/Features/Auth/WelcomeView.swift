import AuthenticationServices
import GoogleSignInSwift
import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var session: AppSession
    @State private var email = ""
    @State private var code = ""
    @State private var challengeID: String?
    @State private var isRequesting = false
    @State private var localError: String?
    @State private var appleNonce: String?

    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var body: some View {
        ZStack {
            PaktlyColor.background.ignoresSafeArea()
            Circle()
                .fill(PaktlyColor.mint.opacity(0.72))
                .frame(width: 380, height: 380)
                .offset(x: 175, y: -350)
                .accessibilityHidden(true)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: 24)
                    PaktlyWordmark(markSize: 42)

                    Text("SHARED PLANS · SHARED GOALS · SHARED MONEY")
                        .font(.caption2.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(PaktlyColor.forest)
                        .padding(.top, 18)

                    Text("Make the plan.\nMake it happen.\nTogether.")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .tracking(-1.1)
                        .minimumScaleFactor(0.75)
                        .padding(.top, 10)

                    Text("From the first idea to the final split, keep the plan, the goal, and the money behind it in one place.")
                        .font(.body)
                        .foregroundStyle(PaktlyColor.secondaryInk)
                        .lineSpacing(3)
                        .padding(.top, 11)

                    VStack(spacing: 14) {
                        if let challengeID {
                            codeStep(challengeID: challengeID)
                        } else {
                            emailStep
                        }
                    }
                    .padding(.top, 20)

                    Text("By continuing, you agree to Paktly’s [Terms](https://paktly.io/terms) and acknowledge the [Privacy Policy](https://paktly.io/privacy).")
                        .font(.caption)
                        .foregroundStyle(PaktlyColor.secondaryInk)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .padding(.top, 16)
                        .padding(.bottom, 20)
                }
                .frame(maxWidth: 520, alignment: .leading)
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .foregroundStyle(PaktlyColor.ink)
    }

    private var emailStep: some View {
        VStack(spacing: 14) {
            SignInWithAppleButton(.continue) { request in
                let nonce = AppleAuthNonce.make()
                appleNonce = nonce
                request.requestedScopes = [.fullName, .email]
                request.nonce = AppleAuthNonce.sha256(nonce)
            } onCompletion: { result in
                handleAppleAuthorization(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .disabled(session.state == .authenticating)

            GoogleSignInButton {
                Task { await session.signInWithGoogle() }
            }
            .frame(height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .disabled(session.state == .authenticating)

            HStack(spacing: 12) {
                Rectangle().fill(PaktlyColor.secondaryInk.opacity(0.18)).frame(height: 1)
                Text("or continue with email")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(PaktlyColor.secondaryInk)
                Rectangle().fill(PaktlyColor.secondaryInk.opacity(0.18)).frame(height: 1)
            }
            .padding(.vertical, 2)

            HStack(spacing: 10) {
                Image(systemName: "envelope")
                    .foregroundStyle(PaktlyColor.secondaryInk)
                TextField("Email address", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.emailAddress)
                    .submitLabel(.continue)
                    .onSubmit { Task { await requestCode() } }
                Button { Task { await requestCode() } } label: {
                    Group {
                        if isRequesting {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "arrow.right")
                        }
                    }
                    .font(.headline)
                    .frame(width: 44, height: 44)
                    .foregroundStyle(.white)
                    .background(PaktlyColor.forest, in: Circle())
                }
                .disabled(isRequesting || !normalizedEmail.contains("@"))
                .accessibilityLabel(isRequesting ? "Sending code" : "Continue with email")
            }
            .frame(height: 54)
            .padding(.horizontal, 14)
            .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(PaktlyColor.secondaryInk.opacity(0.14), lineWidth: 1)
            }
            errorText
        }
    }

    private func codeStep(challengeID: String) -> some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Check your email").font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                Text("Enter the six-digit code sent to \(normalizedEmail).")
                    .font(.subheadline).foregroundStyle(PaktlyColor.secondaryInk)
            }
            TextField("000000", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .multilineTextAlignment(.center)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .padding(16)
                .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                .onChange(of: code) { _, value in code = String(value.filter(\.isNumber).prefix(6)) }

            Button {
                Task { await session.verifyEmailCode(challengeId: challengeID, email: normalizedEmail, code: code) }
            } label: {
                HStack {
                    if session.state == .authenticating { ProgressView().tint(PaktlyColor.background) }
                    Text(session.state == .authenticating ? "Verifying…" : "Verify and continue")
                }
            }
            .buttonStyle(PaktlyPrimaryButtonStyle())
            .disabled(code.count != 6 || session.state == .authenticating)

            Button("Use a different email") {
                self.challengeID = nil
                code = ""
                localError = nil
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(PaktlyColor.forest)
            errorText
        }
    }

    @ViewBuilder private var errorText: some View {
        if let message = localError ?? session.errorMessage {
            Text(message).font(.footnote).foregroundStyle(PaktlyColor.coral)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func requestCode() async {
        guard !isRequesting, normalizedEmail.contains("@") else { return }
        isRequesting = true
        localError = nil
        defer { isRequesting = false }
        do {
            challengeID = try await session.requestEmailCode(normalizedEmail)
        } catch {
            localError = "We couldn’t send a code. Check your email and try again."
        }
    }

    private func handleAppleAuthorization(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case let .success(authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let token = String(data: tokenData, encoding: .utf8),
                let nonce = appleNonce
            else {
                localError = FederatedAuthError.missingToken.localizedDescription
                return
            }
            let name = credential.fullName.flatMap {
                let value = PersonNameComponentsFormatter().string(from: $0).trimmingCharacters(in: .whitespacesAndNewlines)
                return value.isEmpty ? nil : value
            }
            Task {
                await session.completeAppleSignIn(identityToken: token, nonce: nonce, displayName: name)
                appleNonce = nil
            }
        case let .failure(error):
            appleNonce = nil
            if (error as? ASAuthorizationError)?.code != .canceled {
                localError = "Apple sign-in couldn’t be completed. Please try again."
            }
        }
    }
}

struct ProfileSetupView: View {
    @EnvironmentObject private var session: AppSession
    @State private var displayName = ""
    @State private var username = ""
    @State private var usernameStatus: UsernameAvailabilityField.Status = .optional

    private var normalizedUsername: String? {
        let value = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return value.isEmpty ? nil : value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Make it yours")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text("Add the name your groups will recognize. A username is optional.")
                    .foregroundStyle(PaktlyColor.secondaryInk)
            }
            VStack(spacing: 12) {
                TextField("Your name", text: $displayName)
                    .textContentType(.name).textInputAutocapitalization(.words)
                Divider()
                UsernameAvailabilityField(
                    username: $username,
                    currentUsername: nil,
                    status: $usernameStatus
                )
            }
            .padding(17)
            .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            if let message = session.errorMessage {
                Text(message).font(.footnote).foregroundStyle(PaktlyColor.coral)
            }
            Button {
                Task { await session.completeProfile(displayName: displayName, username: normalizedUsername) }
            } label: {
                Text(session.state == .authenticating ? "Saving…" : "Enter Paktly")
            }
            .buttonStyle(PaktlyPrimaryButtonStyle())
            .disabled(
                displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    session.state == .authenticating ||
                    !usernameStatus.permitsSaving
            )
            Spacer()
        }
        .padding(24)
        .background(PaktlyColor.background.ignoresSafeArea())
    }
}
