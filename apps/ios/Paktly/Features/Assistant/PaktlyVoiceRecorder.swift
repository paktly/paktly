@preconcurrency import AVFoundation
import Combine
import Foundation
@preconcurrency import Speech

@MainActor
final class PaktlyVoiceRecorder: ObservableObject {
    enum RecorderError: Error { case microphonePermissionDenied, speechPermissionDenied, unavailable }

    @Published private(set) var isRecording = false
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var liveTranscript = ""
    @Published private(set) var automaticallyCompletedURL: URL?

    private let audioEngine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var speechRequest: SFSpeechAudioBufferRecognitionRequest?
    private var speechTask: SFSpeechRecognitionTask?
    private var progressTask: Task<Void, Never>?
    private var recordingURL: URL?
    private var startedAt: ContinuousClock.Instant?
    private var inputTapInstalled = false

    var formattedDuration: String { String(format: "%d:%02d", Int(duration) / 60, Int(duration) % 60) }

    func start() async throws {
        guard await Self.requestMicrophonePermission() else { throw RecorderError.microphonePermissionDenied }
        guard await Self.requestSpeechPermission() else { throw RecorderError.speechPermissionDenied }
        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else { throw RecorderError.unavailable }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement)
            try session.setActive(true)

            let input = audioEngine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { throw RecorderError.unavailable }

            let url = FileManager.default.temporaryDirectory.appendingPathComponent("paktly-\(UUID().uuidString).wav")
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition

            speechTask = recognizer.recognitionTask(with: request) { @Sendable [weak self] result, _ in
                guard let text = result?.bestTranscription.formattedString else { return }
                Task { @MainActor [weak self] in self?.liveTranscript = text }
            }

            input.installTap(onBus: 0, bufferSize: 1_024, format: format) { @Sendable buffer, _ in
                request.append(buffer)
                try? file.write(from: buffer)
            }
            inputTapInstalled = true

            audioFile = file
            speechRequest = request
            recordingURL = url
            liveTranscript = ""
            duration = 0
            automaticallyCompletedURL = nil
            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true
            startedAt = .now
            startProgressUpdates()
        } catch {
            stopCapture(discarding: true)
            throw error
        }
    }

    func stop() -> URL? {
        let url = recordingURL
        stopCapture(discarding: false)
        return url
    }

    func cancel() { stopCapture(discarding: true) }

    private func startProgressUpdates() {
        progressTask = Task { @MainActor [weak self] in
            while !Task.isCancelled, let self, self.isRecording {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled, self.isRecording, let startedAt = self.startedAt else { return }
                self.duration = Double(startedAt.duration(to: .now).components.seconds)
                if self.duration >= 60 {
                    let completedURL = self.recordingURL
                    self.stopCapture(discarding: false)
                    self.automaticallyCompletedURL = completedURL
                    return
                }
            }
        }
    }

    private func stopCapture(discarding: Bool) {
        progressTask?.cancel()
        progressTask = nil
        if audioEngine.isRunning { audioEngine.stop() }
        if inputTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            inputTapInstalled = false
        }
        speechRequest?.endAudio()
        speechTask?.cancel()
        speechTask = nil
        speechRequest = nil
        audioFile = nil
        isRecording = false
        startedAt = nil
        if discarding, let recordingURL { try? FileManager.default.removeItem(at: recordingURL) }
        if discarding { recordingURL = nil; liveTranscript = "" }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    nonisolated private static func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
    }

    nonisolated private static func requestSpeechPermission() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: return true
        case .denied, .restricted: return false
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
            }
        @unknown default: return false
        }
    }
}
