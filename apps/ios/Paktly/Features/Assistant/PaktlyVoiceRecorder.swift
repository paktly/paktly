@preconcurrency import AVFoundation
import Combine
import Foundation
@preconcurrency import Speech

@MainActor
final class PaktlyVoiceRecorder: ObservableObject {
    enum RecorderError: Error { case microphonePermissionDenied, unavailable }

    @Published private(set) var isRecording = false
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var automaticallyCompletedURL: URL?
    @Published private(set) var liveTranscript = ""

    private let audioEngine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var progressTask: Task<Void, Never>?
    private var recordingURL: URL?
    private var startedAt: ContinuousClock.Instant?
    private var inputTapInstalled = false
    private var audioChunkHandler: (@Sendable (Data) -> Void)?
    private var speechRequest: SFSpeechAudioBufferRecognitionRequest?
    private var speechTask: SFSpeechRecognitionTask?

    var formattedDuration: String { String(format: "%d:%02d", Int(duration) / 60, Int(duration) % 60) }

    func start(audioChunkHandler: (@Sendable (Data) -> Void)? = nil) async throws {
        guard await Self.requestMicrophonePermission() else { throw RecorderError.microphonePermissionDenied }
        self.audioChunkHandler = audioChunkHandler

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement)
            try session.setActive(true)

            let input = audioEngine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { throw RecorderError.unavailable }

            let url = FileManager.default.temporaryDirectory.appendingPathComponent("paktly-\(UUID().uuidString).wav")
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            let speech = makeSpeechPreviewIfAuthorized()
            input.installTap(onBus: 0, bufferSize: 1_024, format: format) { @Sendable buffer, _ in
                try? file.write(from: buffer)
                speech?.append(buffer)
                if let data = Self.pcm16Mono24k(buffer: buffer, sourceRate: format.sampleRate) {
                    audioChunkHandler?(data)
                }
            }
            inputTapInstalled = true

            audioFile = file
            speechRequest = speech
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
        audioFile = nil
        speechRequest?.endAudio(); speechRequest = nil
        speechTask?.cancel(); speechTask = nil
        isRecording = false
        startedAt = nil
        if discarding, let recordingURL { try? FileManager.default.removeItem(at: recordingURL) }
        if discarding { recordingURL = nil }
        audioChunkHandler = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func makeSpeechPreviewIfAuthorized() -> SFSpeechAudioBufferRecognitionRequest? {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized,
              let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else { return nil }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        speechTask = recognizer.recognitionTask(with: request) { @Sendable [weak self] result, _ in
            guard let text = result?.bestTranscription.formattedString else { return }
            Task { @MainActor [weak self] in self?.liveTranscript = text }
        }
        return request
    }

    nonisolated private static func pcm16Mono24k(buffer: AVAudioPCMBuffer, sourceRate: Double) -> Data? {
        guard let channel = buffer.floatChannelData?[0], buffer.frameLength > 0, sourceRate > 0 else { return nil }
        let sourceCount = Int(buffer.frameLength)
        let outputCount = max(1, Int(Double(sourceCount) * 24_000 / sourceRate))
        var output = Data(capacity: outputCount * 2)
        for index in 0..<outputCount {
            let sourceIndex = min(sourceCount - 1, Int(Double(index) * sourceRate / 24_000))
            var sample = Int16(max(-1, min(1, channel[sourceIndex])) * Float(Int16.max)).littleEndian
            withUnsafeBytes(of: &sample) { output.append(contentsOf: $0) }
        }
        return output
    }

    nonisolated private static func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
    }

}
