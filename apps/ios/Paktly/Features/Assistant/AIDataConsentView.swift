import SwiftUI

/// Per-use permission: no child tasks, microphone capture, or uploads before consent.
struct AIDataConsentView<Content: View>: View {
    private let content: () -> Content
    @Environment(\.dismiss) private var dismiss
    @State private var allowed = false

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        if allowed {
            content()
        } else {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Image(systemName: "waveform")
                            .font(.largeTitle).foregroundStyle(PaktlyColor.forest)
                            .accessibilityHidden(true)
                        Text("Before you speak")
                            .font(.largeTitle.bold())
                        Text("This feature uses OpenAI")
                            .font(.headline)
                        Text("With your permission, Paktly sends your audio to OpenAI for transcription. Your transcript, name, account identifier, and shared-plan context—including plan details and member names, usernames, and emails—may also be sent to OpenAI to prepare your request.")
                        Text("Only share information you’re entitled to share. Review the result before saving; AI can make mistakes. You can use the standard forms without AI.")
                            .foregroundStyle(PaktlyColor.secondaryInk)
                        Link("Read the Privacy Policy", destination: URL(string: "https://paktly.io/privacy")!)
                        Button("Allow and continue") { allowed = true }
                            .buttonStyle(PaktlyPrimaryButtonStyle())
                        Button("Not now") { dismiss() }
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .padding(24)
                }
                .background(PaktlyColor.background.ignoresSafeArea())
                .navigationTitle("Your privacy")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            }
        }
    }
}
