import AVFoundation
import Combine
import Foundation

@MainActor
final class PaktlyVoiceRecorder: ObservableObject {
    enum RecorderError: Error { case permissionDenied, unavailable }
    @Published private(set) var isRecording = false
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var automaticallyCompletedURL: URL?
    private var recorder: AVAudioRecorder?
    private var progressTask: Task<Void, Never>?
    private var recordingURL: URL?

    var formattedDuration: String { String(format: "%d:%02d", Int(duration) / 60, Int(duration) % 60) }

    func start() async throws {
        let granted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
        guard granted else { throw RecorderError.permissionDenied }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .spokenAudio, options: [.duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("paktly-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC), AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.prepareToRecord()
        guard recorder.record() else { throw RecorderError.unavailable }
        self.recorder = recorder; recordingURL = url; duration = 0; isRecording = true
        automaticallyCompletedURL = nil
        progressTask = Task { @MainActor [weak self] in
            while !Task.isCancelled, let self, self.isRecording {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled, self.isRecording else { return }
                self.duration = self.recorder?.currentTime ?? self.duration
                if self.duration >= 60 {
                    self.completeAutomatically()
                    return
                }
            }
        }
    }

    func stop() -> URL? { recorder?.stop(); finishSession(); return recordingURL }
    func cancel() {
        recorder?.stop()
        if let recordingURL { try? FileManager.default.removeItem(at: recordingURL) }
        recordingURL = nil; finishSession()
    }

    private func completeAutomatically() {
        let completedURL = recordingURL
        recorder?.stop()
        finishSession()
        automaticallyCompletedURL = completedURL
    }

    private func finishSession() {
        progressTask?.cancel(); progressTask = nil; isRecording = false; recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
