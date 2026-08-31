import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var session: AppSession
    @State private var email = ""
    @State private var code = ""
    @State private var challengeID: String?
    @State private var isRequesting = false
    @State private var localError: String?

    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var body: some View {
        ZStack {
            PaktlyColor.background.ignoresSafeArea()
            Circle()
                .fill(PaktlyColor.mint)
                .frame(width: 420, height: 420)
                .offset(x: 160, y: -330)
                .accessibilityHidden(true)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: 80)
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(PaktlyColor.forest)
                        .padding(17)
                        .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                    Text("Plan together.\nSplit together.\nSave together.")
                        .font(.system(size: 43, weight: .bold, design: .rounded))
                        .tracking(-1.4)
                        .minimumScaleFactor(0.75)
                        .padding(.top, 26)

                    Text("Start with planning and shared expenses. Activate financial features only when you need them.")
                        .font(.title3)
                        .foregroundStyle(PaktlyColor.secondaryInk)
                        .lineSpacing(4)
                        .padding(.top, 16)

                    VStack(spacing: 14) {
                        if let challengeID {
                            codeStep(challengeID: challengeID)
                        } else {
                            emailStep
                        }
                    }
                    .padding(.top, 38)

                    Text("No wallet or financial account is created during signup.")
                        .font(.footnote)
                        .foregroundStyle(PaktlyColor.secondaryInk)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 16)
                }
                .padding(24)
            }
        }
        .foregroundStyle(PaktlyColor.ink)
    }

    private var emailStep: some View {
        VStack(spacing: 14) {
            TextField("Email address", text: $email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.emailAddress)
                .padding(16)
                .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 17, style: .continuous))

            Button { Task { await requestCode() } } label: {
                HStack {
                    if isRequesting { ProgressView().tint(PaktlyColor.background) }
                    Text(isRequesting ? "Sending code…" : "Continue with email")
                }
            }
            .buttonStyle(PaktlyPrimaryButtonStyle())
            .disabled(isRequesting || !normalizedEmail.contains("@"))

            HStack(spacing: 12) {
                Rectangle().fill(PaktlyColor.secondaryInk.opacity(0.18)).frame(height: 1)
                Text("or").font(.footnote).foregroundStyle(PaktlyColor.secondaryInk)
                Rectangle().fill(PaktlyColor.secondaryInk.opacity(0.18)).frame(height: 1)
            }

            Button {
                Task { await session.signInWithExistingPasskey() }
            } label: {
                Label(
                    session.state == .authenticating ? "Opening passkey…" : "Sign in with an existing passkey",
                    systemImage: "person.badge.key.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PaktlySecondaryButtonStyle())
            .disabled(session.state == .authenticating)
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
}

struct ProfileSetupView: View {
    @EnvironmentObject private var session: AppSession
    @State private var displayName = ""
    @State private var username = ""

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
                TextField("Username (optional)", text: $username)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
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
            .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || session.state == .authenticating)
            Spacer()
        }
        .padding(24)
        .background(PaktlyColor.background.ignoresSafeArea())
    }
}
