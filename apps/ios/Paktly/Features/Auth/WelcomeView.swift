import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var session: AppSession

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
                    Task { await session.authenticate(mode: .signIn) }
                } label: {
                    HStack {
                        if session.state == .authenticating {
                            ProgressView().tint(PaktlyColor.background)
                        } else {
                            Image(systemName: "faceid")
                        }
                        Text(session.state == .authenticating ? "Signing in…" : "Continue with passkey")
                    }
                }
                .buttonStyle(PaktlyPrimaryButtonStyle())
                .disabled(session.state == .authenticating)

                Button {
                    Task {
                        await session.authenticate(mode: .signUp)
                    }
                } label: {
                    Text("Create an account")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .foregroundStyle(PaktlyColor.forest)
                .padding(.top, 18)
                .disabled(session.state == .authenticating)

                if session.state == .failed {
                    Text("We couldn’t sign you in. Please try again.")
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
    }
}
