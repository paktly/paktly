import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var session: AppSession
    @State private var email = ""
    @State private var code = ""
    @State private var challengeID: String?
    @State private var isRequesting = false
    @State private var localError: String?
    @State private var unavailableProvider = ""
    @State private var showingProviderNotice = false

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
                    Spacer(minLength: 48)
                    HStack(spacing: 10) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(PaktlyColor.forest)
                            .frame(width: 42, height: 42)
                            .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        Text("paktly")
                            .font(.system(size: 25, weight: .bold, design: .rounded))
                            .tracking(-0.5)
                    }

                    Text("Plan together.\nSplit together.\nSave together.")
                        .font(.system(size: 39, weight: .bold, design: .rounded))
                        .tracking(-1.1)
                        .minimumScaleFactor(0.75)
                        .padding(.top, 24)

                    Text("One place for shared plans, expenses, and goals—with smarter money features when you need them.")
                        .font(.body)
                        .foregroundStyle(PaktlyColor.secondaryInk)
                        .lineSpacing(3)
                        .padding(.top, 13)

                    VStack(spacing: 14) {
                        if let challengeID {
                            codeStep(challengeID: challengeID)
                        } else {
                            emailStep
                        }
                    }
                    .padding(.top, 30)

                    Text("By continuing, you agree to Paktly’s [Terms](https://paktly.io/terms) and acknowledge the [Privacy Policy](https://paktly.io/privacy).")
                        .font(.caption)
                        .foregroundStyle(PaktlyColor.secondaryInk)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .padding(.top, 18)
                        .padding(.bottom, 24)
                }
                .padding(24)
            }
        }
        .foregroundStyle(PaktlyColor.ink)
        .alert("(unavailableProvider) sign-in", isPresented: $showingProviderNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This option is being connected and will be available soon. Continue with email for now.")
        }
    }

    private var emailStep: some View {
        VStack(spacing: 14) {
            SocialAuthButton(title: "Continue with Apple", systemImage: "apple.logo", style: .dark) {
                showUnavailable("Apple")
            }

            SocialAuthButton(title: "Continue with Google", lettermark: "G", style: .light) {
                showUnavailable("Google")
            }

            HStack(spacing: 12) {
                Rectangle().fill(PaktlyColor.secondaryInk.opacity(0.18)).frame(height: 1)
                Text("or continue with email")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(PaktlyColor.secondaryInk)
                Rectangle().fill(PaktlyColor.secondaryInk.opacity(0.18)).frame(height: 1)
            }
            .padding(.vertical, 2)

            TextField("Email address", text: $email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.emailAddress)
                .padding(16)
                .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(PaktlyColor.secondaryInk.opacity(0.14), lineWidth: 1)
                }

            Button { Task { await requestCode() } } label: {
                HStack {
                    if isRequesting { ProgressView().tint(PaktlyColor.background) }
                    Text(isRequesting ? "Sending code…" : "Continue with email")
                }
            }
            .buttonStyle(PaktlyPrimaryButtonStyle())
            .disabled(isRequesting || !normalizedEmail.contains("@"))
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
        guard !isRequesting else { return }
        isRequesting = true
        localError = nil
        defer { isRequesting = false }
        do {
            challengeID = try await session.requestEmailCode(normalizedEmail)
        } catch {
            localError = "We couldn’t send a code. Check your email and try again."
        }
    }

    private func showUnavailable(_ provider: String) {
        unavailableProvider = provider
        showingProviderNotice = true
    }
}

private struct SocialAuthButton: View {
    enum Style { case dark, light }

    let title: String
    var systemImage: String?
    var lettermark: String?
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title).font(.headline)
                HStack {
                    if let systemImage {
                        Image(systemName: systemImage).font(.system(size: 19, weight: .semibold))
                    } else if let lettermark {
                        Text(lettermark).font(.system(size: 19, weight: .bold, design: .rounded))
                    }
                    Spacer()
                    Text("Soon")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            (style == .dark ? Color.white.opacity(0.16) : PaktlyColor.mint.opacity(0.45)),
                            in: Capsule()
                        )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .foregroundStyle(style == .dark ? Color.white : PaktlyColor.ink)
            .background(style == .dark ? Color.black : PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay {
                if style == .light {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(PaktlyColor.secondaryInk.opacity(0.14), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
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
