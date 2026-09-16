import AVFoundation
import SwiftUI

/// Ask iOS for microphone access first, without a custom pre-permission alert.
/// Separate, per-use AI consent still precedes all capture and uploads.
struct AIDataConsentView<Content: View>: View {
    private let content: () -> Content
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var allowed = false
    @State private var microphoneGranted: Bool?

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        if microphoneGranted == nil {
            ProgressView("Opening microphone…")
                .task {
                    microphoneGranted = await PaktlyVoiceRecorder.requestMicrophonePermission()
                }
        } else if microphoneGranted == false {
            NavigationStack {
                VStack(spacing: 24) {
                    Text("Microphone access is off")
                        .font(.title2.bold())
                    Text("To use voice input, enable microphone access for Paktly in Settings. You can still use the standard forms without it.")
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    .buttonStyle(PaktlyPrimaryButtonStyle())
                }
                .padding(24)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        microphoneGranted = AVAudioApplication.shared.recordPermission == .granted
                    }
                }
            }
        } else if allowed {
            content()
        } else {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Image(systemName: "waveform")
                            .font(.largeTitle).foregroundStyle(PaktlyColor.forest)
                            .accessibilityHidden(true)
                        Text("AI data sharing")
                            .font(.largeTitle.bold())
                        Text("This feature uses OpenAI")
                            .font(.headline)
                        Text("With your permission, Paktly sends your audio to OpenAI for transcription. Your transcript, name, account identifier, and shared-plan context—including plan details and member names, usernames, and emails—may also be sent to OpenAI to prepare your request.")
                        Text("Only share information you’re entitled to share. Review the result before saving; AI can make mistakes. You can use the standard forms without AI.")
                            .foregroundStyle(PaktlyColor.secondaryInk)
                        Link("Read the Privacy Policy", destination: URL(string: "https://paktly.io/privacy")!)
                        Button("Continue") { allowed = true }
                            .buttonStyle(PaktlyPrimaryButtonStyle())
                        Button("Don’t use AI") { dismiss() }
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
